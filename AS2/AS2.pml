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
        WAC_id = connected_WAC[i];
        WAC_buffer_in[WAC_id]!disconn;
        connected_WAC[i] = -1;
    }
    num_connected = 0;
}

// Initially, CM idle status, WCP enabled, all WACs disconnected

proctype CM()
{
                byte num_connected;
                byte connected_WAC[num_WAC];
                int i;
                bool succ_flag;

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
                goto s_updating

s_updating:     // wait for all connected WAC to respond
                succ_flag = true;                
                for (i : 0 .. num_connected-1) {
                    WAC_id = connected_WAC[i];
                    WAC_buffer_out[WAC_id]?msg
                    if 
                    ::  msg == get_new_winfo_fail;
                        succ_flag = false;
                    ::  else;
                        skip;
                    fi;
                }

                if 
                ::  succ_flag == false;
                    send_to_connected(use_old_winfo);
                    goto s_post_reverting
                ::  else;
                    send_to_connected(use_new_winfo);
                    goto s_post_updating
                fi;

s_post_updating:    succ_flag = true;
                    for (i : 0 .. num_connected-1) {
                        WAC_id = connected_WAC[i];
                        WAC_buffer_out[WAC_id]?msg
                        if 
                        ::  msg == use_new_winfo_fail;
                            succ_flag = false;
                            WAC_buffer_in[WAC_id]!disconn;
                        ::  else;
                            skip
                        fi;
                    }
                    if 
                    ::  succ_flag == false;
                        num_connected = 0;
                        WCP_buffer!enable_WCP;
                        goto s_idle;
                    ::  else;                    
                        WCP_buffer!enable_WCP;
                        goto s_idle
                    fi;

s_post_reverting:   succ_flag = true;
                    for (i : 0 .. num_connected-1) {
                        WAC_id = connected_WAC[i];
                        WAC_buffer_out[WAC_id]?msg;
                        if 
                        ::  msg == use_old_winfo_fail;
                            succ_flag = false;
                            WAC_buffer_in[WAC_id]!disconn;
                        ::  else;
                            skip;
                        fi;
                    }
                    if
                    ::  succ_flag == false;
                        num_connected = 0;
                        WCP_buffer!enable_WCP;
                        goto s_idle;
                    ::  else;
                        WCP_buffer!enable_WCP;
                        goto s_idle
                    fi;
}

proctype WCP()
{
    bool WCP_enabled = true;

    do
    ::  WCP_buffer??enable_WCP;
        WCP_enabled = true;

    ::  WCP_buffer??disable_WCP;
        WCP_enabled = false;

    ::  WCP_enabled == true;
        if
        ::  // check if buffer already contains the msg
            CM_buffer??[update_CM, 255] == false;
            CM_buffer!update_CM, 255;
        ::  else;
            skip;
        fi;
    od;
}

proctype WAC(byte id)
{
                mtype msg;
                bool conn_req_ready = true;
                bool connected = false;

s_idle:         do 
                ::  conn_req_ready == true;
                    CM_buffer!conn_req, id;
                    conn_req_ready = false;

                ::  WAC_buffer_in[id]??conn_succ;
                    goto s_pre_init

                ::  WAC_buffer_in[id]??conn_fail;
                    conn_req_ready = true;

                ::  WAC_buffer_in[id]??wupdate;
                    goto s_pre_updating
                od;

s_pre_init:     WAC_buffer_in[id]??get_new_winfo;
                goto s_init

s_init:         if
                ::  WAC_buffer_out[id]!get_new_winfo_succ;
                    WAC_buffer_in[id]??use_new_winfo;
                    goto s_post_init;
                ::  WAC_buffer_out[id]!get_new_winfo_fail;
                    conn_req_ready = true;
                    goto s_idle
                fi;

s_post_init:    if
                ::  WAC_buffer_out[id]!use_new_winfo_succ
                    connected = true;
                ::  WAC_buffer_out[id]!use_new_winfo_fail
                    conn_req_ready = true;
                fi;
                goto s_idle

s_pre_updating: WAC_buffer_in[id]??get_new_winfo;
                if
                ::  WAC_buffer_out[id]!get_new_winfo_succ;
                    if
                    ::  WAC_buffer_in[id]??use_new_winfo;
                        goto s_post_updating
                    ::  WAC_buffer_in[id]??use_old_winfo;
                        goto s_post_reverting
                    fi;     
                ::  WAC_buffer_out[id]!get_new_winfo_fail;
                    WAC_buffer_in[id]??use_old_winfo;
                    goto s_post_reverting
                fi;

s_post_updating:    if
                    ::  WAC_buffer_out[id]!use_new_winfo_succ;
                        goto s_idle
                    ::  WAC_buffer_out[id]!use_new_winfo_fail;
                        WAC_buffer_in[id]??disconn;
                        connected = false;
                        conn_req_ready = true;
                        goto s_idle
                    fi;

s_post_reverting:   if
                    ::  WAC_buffer_out[id]!use_old_winfo_succ;
                        goto s_idle
                    ::  WAC_buffer_out[id]!use_old_winfo_fail;
                        WAC_buffer_in[id]??disconn;
                        connected = false;
                        conn_req_ready = true;
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

