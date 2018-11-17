#define num_WAC 3

mtype = { conn_succ, conn_fail, get_new_winfo, goto_init, use_new_winfo, goto_post_init, goto_idle, disable_WCP, enable_WCP, conn_req, get_new_winfo_succ, get_new_winfo_fail, use_new_winfo_succ, use_new_winfo_fail, use_old_winfo, use_old_winfo_succ, use_old_winfo_fail, update_CM };

chan CM_buffer = [5] of { mtype, byte };
chan WAC_buffer[num_WAC] = [1] of { mtype };
chan WCP_buffer = [1] of { mtype };

proctype CM()
{
                // keep track of all connected WAC
                byte num_connected;
                byte connected_WAC[num_WAC];
                byte i;

                mtype msg;
                byte WAC_id;

s_idle:         CM_buffer?msg, WAC_id;
                if
                ::  msg == conn_req;
                    WAC_buffer[WAC_id]!conn_succ;
                    WCP_buffer!disable_WCP;
                    goto s_pre_init
                ::  msg == update_CM;
                    // for all connected WAC, send goto_pre_updating


                    WCP_buffer!disable_WCP;
                    goto s_pre_updating
                fi;

s_pre_init:     WAC_buffer[WAC_id]!get_new_winfo;
                WAC_buffer[WAC_id]!goto_init;
                goto s_init

s_init:         CM_buffer?msg, WAC_id;
                if
                ::  msg == get_new_winfo_succ;
                    WAC_buffer[WAC_id]!use_new_winfo;
                    WAC_buffer[WAC_id]!goto_post_init;
                    goto s_post_init
                ::  msg == get_new_winfo_fail;
                    WAC_buffer[WAC_id]!goto_idle;
                    goto s_idle  
                fi;

s_post_init:    CM_buffer?msg, WAC_id;
                if
                ::  msg == use_new_winfo_succ;
                    WAC_buffer[WAC_id]!goto_idle;
                    WCP_buffer!enable_WCP;
                    goto s_idle
                ::  msg == use_new_winfo_fail;
                    WAC_buffer[WAC_id]!goto_idle;
                    WCP_buffer!enable_WCP;
                    goto s_idle             
                fi;

s_pre_updating: // send all connected WAC get_new_winfo
                for (i : 0 .. num_connected) {
                    WAC_id = connected_WAC[i];
                    WAC_buffer[WAC_id]!get_new_winfo;
                }
                
                // TODO: connected WAC status = updating [set by CM]

                goto s_updating

s_updating:     // wait for all connected WAC to respond
                for (i : 0 .. num_connected) {
                    WAC_id = connected_WAC[i];
                    CM_buffer?msg, WAC_id;
                    if 
                    ::  msg == get_new_winfo_fail;
                        for (i : 0 .. num_connected) {
                            WAC_id = connected_WAC[i];
                            WAC_buffer[WAC_id]!use_old_winfo;
                        }
                        goto s_post_reverting
                    fi;
                }
                // assume all succ since no one other msg should be sent
                goto s_post_updating

s_post_updating:    for (i : 0 .. num_connected) {
                        WAC_id = connected_WAC[i];
                        CM_buffer?msg, WAC_id;
                        if 
                        ::  msg == use_new_winfo_fail;
                            // disconnect all WAC
                            for (i : 0 .. num_connected) {
                                WAC_buffer[WAC_id]!disconn;
                                connected_WAC[i] = -1;
                                num_connected = 0;
                            }
                            WCP_buffer!enable_WCP;
                            goto s_idle;
                        fi;
                    }
                    // assume all succ since no one other msg should be sent
                    for (i : 0 .. num_connected) {
                        WAC_id = connected_WAC[i];
                        WAC_buffer[WAC_id]!goto_idle;
                    }
                    WCP_buffer!enable_WCP;
                    goto s_idle

s_post_reverting:   for (i : 0 .. num_connected) {
                        WAC_id = connected_WAC[i];
                        CM_buffer?msg, WAC_id;
                        if 
                        ::  msg == use_old_winfo_fail;
                            // disconnect all WAC
                            for (i : 0 .. num_connected) {
                                WAC_buffer[WAC_id]!disconn;
                                connected_WAC[i] = -1;
                                num_connected = 0;
                            }
                            WCP_buffer!enable_WCP;
                            goto s_idle;
                        fi;
                    }
                    // assume all succ since no one other msg should be sent
                    for (i : 0 .. num_connected) {
                        WAC_id = connected_WAC[i];
                        WAC_buffer[WAC_id]!goto_idle;
                    }
                    WCP_buffer!enable_WCP;
                    goto s_idle

}

proctype WCP()
{

s_enabled:      if
                ::  WCP_buffer??disable_WCP;
                    goto s_disabled
                ::  CM_buffer!update_CM;
                ::  true; // do nothing
                fi;

s_disabled:     WCP_buffer??enable_WCP;
                goto s_enabled
}

proctype WAC(byte id)
{
                mtype msg;
                bool connected = false;

s_idle:         do 
                ::  goto s_idle
                ::  CM_buffer!conn_req, id
                    if  // execution blocks if none of the guards are executable
                    ::  WAC_buffer[id]??conn_succ 
                        goto s_pre_init
                    ::  WAC_buffer[id]??conn_fail
                        goto s_idle
                    fi;
                ::  // if buffer not empty
                    if
                    ::  nempty(WAC_buffer[id]);
                        WAC_buffer[id]??goto_pre_updating;
                    fi;
                od;

s_pre_init:     WAC_buffer[id]??get_new_winfo;
                WAC_buffer[id]??goto_init;
                goto s_init

s_init:         if
                ::  CM_buffer!get_new_winfo_succ, id
                    WAC_buffer[id]??use_new_winfo
                    WAC_buffer[id]??goto_post_init
                    goto s_post_init
                ::  CM_buffer!get_new_winfo_fail, id
                    WAC_buffer[id]??goto_idle
                    goto s_idle
                fi;

s_post_init:    if
                ::  CM_buffer!use_new_winfo_succ, id
                    WAC_buffer[id]??goto_idle
                    goto s_idle
                ::  CM_buffer!use_new_winfo_fail, id
                    WAC_buffer[id]??goto_idle
                    goto s_idle
                fi;
}

init {
    atomic {
        run CM();
        run WCP();
        int i;
        for (i : 0 .. num_WAC-1) {
            run WAC(i);
        }
    }
}

// LTL: if user click WCP button to update_winfo, connected WAC reply get_new_winfo_succ

