#define num_WAC 5

mtype = { conn_succ, conn_fail, get_new_winfo, st_init, use_new_winfo, st_post_init, disconn, disable_WCP, enable_WCP, conn_req, get_new_winfo_succ, get_new_winfo_fail, use_new_winfo_succ, use_new_winfo_fail, update_CM };

chan CM_buffer = [5] of { mtype, byte };
chan WAC_buffer[num_WAC] = [1] of { mtype };
chan WCP_buffer = [1] of { mtype };

proctype CM()
{
            // keep track of all connected WAC

            mtype msg;
            byte WCP_id;

idle:       CM_buffer?msg, WCP_id;
            if
            ::  msg == conn_req;
                WAC_buffer[WCP_id]!conn_succ;
                WCP_buffer!disable_WCP;
                goto pre_init
            ::  msg == update_CM;
            fi;

pre_init:   WAC_buffer[id]!get_new_winfo;
            WAC_buffer[id]!st_init;
            goto init

init:       if
            ::  CM_buffer??get_new_winfo_succ, id;
                WAC_buffer[id]!use_new_winfo;
                WAC_buffer[id]!st_post_init;
                goto post_init
            ::  CM_buffer??get_new_winfo_fail, id;
                WAC_buffer[id]!disconn;
                goto idle  
            fi;

post_init:  if
            ::  CM_buffer??use_new_winfo_succ, id;
                WAC_buffer[id]!disconn;
                WCP_buffer!enable_WCP;
                goto idle
            ::  CM_buffer??use_new_winfo_fail, id;
                WAC_buffer[id]!disconn;
                WCP_buffer!enable_WCP;
                goto idle             
            fi;
}

proctype WCP()
{

enabled:    if
            ::  WCP_buffer??disable_WCP;
                goto   disabled
            ::  CM_buffer!update_CM;
            ::  //do nothing
            fi;

disabled:   WCP_buffer??enable_WCP;
            goto   enabled

}

proctype WAC(byte id)
{
            mtype msg;
            byte id;

idle:       do 
            ::  goto idle
            ::  CM_buffer!conn_req, id
                if  // execution blocks if none of the guards are executable
                ::  WAC_buffer??conn_succ 
                    goto pre_init
                ::  WAC_buffer??conn_fail
                    goto idle
                fi;
            od;

pre_init:   WAC_buffer??get_new_winfo
            WAC_buffer??st_init
            goto init

init:       ::  CM_buffer!get_new_winfo_succ, id
                WAC_buffer??use_new_winfo
                WAC_buffer??st_post_init
                goto post_init
            ::  CM_buffer!get_new_winfo_fail, id
                WAC_buffer??disconn
                goto idle

post_init:  ::  CM_buffer!use_new_winfo_succ, id
                WAC_buffer??st_idle
                goto idle
            ::  CM_buffer!use_new_winfo_fail, id
                WAC_buffer??disconn
                goto idle
}

init {
    atomic {
        run CM();
        run WCP();
        run WAC(0);
    }
}

