#define num_WAC = 5

CM_out = { conn_succ, conn_fail, get_new_winfo, st_init, use_new_winfo, st_post-init, disconn, disable_WCP, enable_WCP };
CM_in = { conn_req, get_new_winfo_succ, get_new_winfo_fail, use_new_winfo_succ, use_new_winfo_fail, update_CM };

chan CM_buffer[1] = [5] of { CM_in, byte WAC_id };
chan WAC_buffer[num_WAC] = [1] of { CM_out };
chan WCP_buffer[1] = [1] of { CM_out };

proctype CM()
{
// keep track of all connected WAC
            byte id;

idle:       if
            ::  CM_buffer??conn_req, id;
                WAC_buffer[id]!conn_succ;
                WCP_buffer!disable_WCP;
                goto: pre-init;
            ::  CM_buffer??update_CM;
            fi

pre-init:   WAC_buffer[id]!get_new_winfo;
            WAC_buffer[id]!st_init;
            goto: init

init:       
            
}

proctype WCP()
{

}

proctype WAC(byte id)
{
            mtype msg;

idle:       do 
            ::  goto: idle
            ::  CM_buffer!conn_req, id
                if  // execution blocks if none of the guards are executable
                ::  WAC_buffer??conn_succ 
                    goto: pre-init
                ::  WAC_buffer??conn_fail
                    goto: idle
                fi
            od

pre-init:   WAC_buffer??get_new_winfo
            WAC_buffer??st_init
            goto: init

init:       ::  CM_buffer!get_new_winfo_succ, id
                WAC_buffer??use_new_winfo
                WAC_buffer??st_post-init
                goto: post-init
            ::  CM_buffer!get_new_winfo_fail, id
                WAC_buffer??disconn
                goto: idle

post-init:  ::  CM_buffer!use_new_winfo_succ, id
                WAC_buffer??st_idle
                goto: idle
            ::  CM_buffer!use_new_winfo_fail, id
                WAC_buffer??disconn
                goto: idle
}

init {
    atomic {
        
    }
}





