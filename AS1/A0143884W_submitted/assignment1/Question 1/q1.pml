#define true 1
#define false 0
#define p0 (up[0] == start)
#define q0 (down[0] == stop)
#define p1 (up[1] == start)
#define q1 (down[1] == stop)

bool busy[2];
bool start_sent[2];

mtype = {start, stop, data, ack};

chan up[2] = [1] of { mtype };
chan down[2] = [1] of { mtype };

proctype station(byte id; chan in; chan out; byte chan_id)
{
    do
        ::  in?start ->
            //atomic { busy[id] == false -> busy[id] = true }; //removed this
            out!ack;
            do
                :: in?data -> out!data
                :: in?stop -> break
            od;
            out!stop;
            //busy[id] = false;
        ::  atomic { (busy[id] == false && start_sent[chan_id] == false) -> busy[id] = true; start_sent[chan_id] = true }; //added start_sent
            out!start;
            in?ack;
            do
                :: out!data -> in?data
                   out!stop -> break
            od;
            in?stop;
            atomic { busy[id] = false; start_sent[chan_id] = false }
        od
}

init {
    atomic {
        run station(0, up[1], down[1], 1);
        run station(1, up[0], down[0], 0);
        run station(0, down[0], up[0], 0);
        run station(1, down[1], up[1], 1);
    }
}

// any communication that is started, is finished, model is defined by claim
ltl v0 { []( (p0 -> (<> q0) ) && (p1 -> (<> q1) ) ) }