mtype = {red, green, blue};

chan red_stream = [0] of { mtype };
chan green_stream = [0] of { mtype };
chan blue_stream = [0] of { mtype };

chan buffer = [5] of { mtype };

bool pkt_sent = false;

byte red_count = 0;
byte green_count = 0;
byte blue_count = 0;

proctype red_in()
{
    do
        ::  red_stream!red;
    od;
}

proctype green_in()
{
    do
        ::  green_stream!green;
    od;
}

proctype blue_in()
{
    do
        ::  blue_stream!blue;
    od;
}

proctype assemble()
{
    mtype msg;
    do 
        ::  atomic {
                red_stream?msg;
                buffer!msg;
                red_count = red_count + 1;
            }
        ::  atomic {
                green_stream?msg;
                buffer!msg;
                green_count = green_count + 1;
            }
        ::  atomic {
                blue_stream?msg;
                buffer!msg;
                blue_count = blue_count + 1;
            }
        ::  (red_count > 0 && green_count > 0 && blue_count > 0) ->
cs:         atomic {
                buffer??red;
                buffer??green;
                buffer??blue;
                red_count = red_count - 1;
                green_count = green_count - 1;
                blue_count = blue_count - 1;
            }
    od;
}

init {
    atomic {
        run red_in()
        run green_in()
        run blue_in()
        run assemble()
    }
}

// globally, eventually cp will be reached by process assemble()
ltl v0 { [] <> (assemble@cs) }