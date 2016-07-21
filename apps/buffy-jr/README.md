Be sure to listen on 9000 to simulate metrics receiver.

Binaries:
1 – four pass pass array
2 – creates string and  convert string to array
3 – creates string and passes string along down the chain
4 – each step expects any and matches on string
5 – convert initial value to u64  and each step matches on u64
6 – using guids
7 – report Epoch.nanoseconds
8 - match on step output
10 -  add metrics collector
11 – use six steps instead of two
12 – use five steps
13 – pass along result of computation (5 steps)
14 – pass along result of computation without collecting (5 steps)
15 – same with three steps
16 – same but with collecting
17 – pass value times two at each step (3 steps)
18 - same but with 5 steps

My initial results:
1 – 130k
2 – 130k
3 – 130k
4 – 130k
5 – 130k
6 – 130k
7 – 130k
8 - 130k
10 - 130k
11 – 113k (but without collecting it was 130k)
12 – 130k
13 – 45k
14 – 52k
15 – 105k
16 – 105k
17 – 97k
18 - 47k
