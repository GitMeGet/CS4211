#define num_WAC 3

mtype = { update_CM, wupdate, conn_req, conn_succ, conn_fail, disconn, disable_WCP, enable_WCP, get_new_winfo_succ, get_new_winfo, get_new_winfo_fail, use_new_winfo, use_new_winfo_succ, use_new_winfo_fail, use_old_winfo, use_old_winfo_succ, use_old_winfo_fail };

chan CM_buffer = [5] of { mtype, byte };
chan WAC_buffer_in[num_WAC] = [1] of { mtype };
chan WAC_buffer_out[num_WAC] = [1] of { mtype };
chan WCP_buffer = [1] of { mtype };

inline send_to_connected(msg) {
    for (i : 0 .. num_connected-1) {
        WAC_id = connected_WAC[i];
        WAC_buffer_in[WAC_id]!msg;
    }   
}

inline disconn_all_WAC() {
    for (i : 0 .. num_connected-1) {
        WAC_buffer_in[WAC_id]!disconn;
        connected_WAC[i] = -1;
        num_connected = 0;
    }
}

// Initially, CM idle status, WCP enabled, all WACs disconnected

proctype CM()
{
                byte num_connected;
                byte connected_WAC[num_WAC];
                int i;

                mtype msg;
                byte WAC_id;

s_idle:         CM_buffer?msg, WAC_id;
                if
                ::  msg == conn_req;
                    WAC_buffer_in[WAC_id]!conn_succ;
                    WCP_buffer!disable_WCP;
                    goto s_pre_init
                ::  msg == update_CM;
                    if 
                    ::  num_connected == 0;
                        goto s_idle
                    ::  else;
                        send_to_connected(wupdate);
                        WCP_buffer!disable_WCP;
                        goto s_pre_updating
                    fi;
                fi;

s_pre_init:     WAC_buffer_in[WAC_id]!get_new_winfo;
                goto s_init

s_init:         if
                ::  WAC_buffer_out[WAC_id]??get_new_winfo_succ;
                    WAC_buffer_in[WAC_id]!use_new_winfo;
                    goto s_post_init
                ::  WAC_buffer_out[WAC_id]??get_new_winfo_fail;
                    goto s_idle  
                fi;

s_post_init:    if
                ::  WAC_buffer_out[WAC_id]??use_new_winfo_succ;
                    connected_WAC[num_connected] = WAC_id;
                    num_connected = num_connected + 1;
                ::  WAC_buffer_out[WAC_id]??use_new_winfo_fail;       
                fi;
                WCP_buffer!enable_WCP;
                goto s_idle

s_pre_updating: send_to_connected(get_new_winfo);
                
                // TODO: connected WAC status = updating [set by CM]

                goto s_updating

s_updating:     // wait for all connected WAC to respond
                for (i : 0 .. num_connected) {
                    WAC_id = connected_WAC[i];
                    CM_buffer?msg, WAC_id;
                    if 
                    ::  msg == get_new_winfo_fail;
                        send_to_connected(use_old_winfo);
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
                            disconn_all_WAC();
                            WCP_buffer!enable_WCP;
                            goto s_idle;
                        fi;
                    }
                    // assume all succ since no one other msg should be sent
                    for (i : 0 .. num_connected) {
                        WAC_id = connected_WAC[i];
                    }
                    WCP_buffer!enable_WCP;
                    goto s_idle

s_post_reverting:   for (i : 0 .. num_connected) {
                        WAC_id = connected_WAC[i];
                        CM_buffer?msg, WAC_id;
                        if 
                        ::  msg == use_old_winfo_fail;
                            disconn_all_WAC();
                            WCP_buffer!enable_WCP;
                            goto s_idle;
                        fi;
                    }
                    // assume all succ since no one other msg should be sent
                    for (i : 0 .. num_connected) {
                        WAC_id = connected_WAC[i];
                    }
                    WCP_buffer!enable_WCP;
                    goto s_idle
}

proctype WCP()
{
    bool update_CM_sent = false;
    bool WCP_enabled = true;

    do
    ::  WCP_buffer??enable_WCP;
        WCP_enabled = true;

    ::  WCP_buffer??disable_WCP;
        WCP_enabled = false;

    ::  WCP_enabled == true;
        // TODO: add delay instead of using flag
        if 
        ::  update_CM_sent == false;
            CM_buffer!update_CM, -1;
            update_CM_sent = true;
        ::  else;
            skip
        fi;
    od;
}

proctype WAC(byte id)
{
                mtype msg;
                bool connected = false;

s_idle:         do 
                ::  goto s_idle
                ::  CM_buffer!conn_req, id
                    if  // execution blocks if none of the guards are executable
                    ::  WAC_buffer_in[id]??conn_succ 
                        goto s_pre_init
                    ::  WAC_buffer_in[id]??conn_fail
                        goto s_idle
                    fi;
                ::  WAC_buffer_in[id]??wupdate;
                    goto s_pre_updating
                od;

s_pre_init:     WAC_buffer_in[id]??get_new_winfo;
                goto s_init

s_init:         if
                ::  WAC_buffer_out[id]!get_new_winfo_succ
                    WAC_buffer_in[id]??use_new_winfo
                    goto s_post_init
                ::  WAC_buffer_out[id]!get_new_winfo_fail
                    goto s_idle
                fi;

s_post_init:    if
                ::  WAC_buffer_out[id]!use_new_winfo_succ
                ::  WAC_buffer_out[id]!use_new_winfo_fail
                fi;
                goto s_idle

s_pre_updating: WAC_buffer_in[id]??get_new_winfo;
                if
                ::  CM_buffer!get_new_winfo_succ, id;
                    goto s_post_updating
                ::  CM_buffer!get_new_winfo_fail, id;
                    goto s_post_reverting
                fi;

s_post_updating:    WAC_buffer_in[id]??use_new_winfo;
                    if
                    ::  CM_buffer!use_new_winfo_succ, id;
                        goto s_idle
                    ::  CM_buffer!use_new_winfo_fail, id;
                        WAC_buffer_in[id]??disconn;
                        connected = false;
                        goto s_idle
                    fi;

s_post_reverting:   WAC_buffer_in[id]??use_old_winfo;
                    if
                    ::  CM_buffer!use_old_winfo_succ, id;
                        goto s_idle
                    ::  CM_buffer!use_old_winfo_fail, id;
                        WAC_buffer_in[id]??disconn;
                        connected = false;
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

