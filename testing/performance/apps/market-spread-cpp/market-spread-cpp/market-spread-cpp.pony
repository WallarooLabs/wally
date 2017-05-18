"""
Setting up a market-spread-cpp run (in order):
1) reports sink:
nc -l 127.0.0.1 5555 >> /dev/null

2) metrics sink:
nc -l 127.0.0.1 5001 >> /dev/null

3a) single worker
./market-spread-cpp -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:501 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker-name --ponythreads=4 --ponynoblock

3b) multi-worker
./market-spread-cpp -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name --ponythreads=4 --ponynoblock -t -w 2

./market-spread-cpp -i 127.0.0.1:7000,127.0.0.1:7001 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker2 --ponythreads=4 --ponynoblock -w 2

4) initialization:
giles/sender/sender -h 127.0.0.1:7000 -m 5000000 -s 300 -i 5_000_000 -f demos/marketspread/initial-nbbo-fixish.msg -r --ponythreads=1 -y -g 57 -w

5) orders:
giles/sender/sender -h 127.0.0.1:7000 -m 5000000 -s 300 -i 5_000_000 -f demos/marketspread/r3k-orders-fixish.msg -r --ponythreads=1 -y -g 57 -w

6) nbbo:
giles/sender/sender -h 127.0.0.1:7001 -m 10000000 -s 300 -i 2_500_000 -f demos/marketspread/r3k-nbbo-fixish.msg -r --ponythreads=1 -y -g 46 -w
"""

use "wallaroo/cpp_api/pony"

use "lib:wallaroo"
use "lib:c++" if osx
use "lib:stdc++" if linux

use "lib:market-spread-cpp"

actor Main
  new create(env: Env) =>
    WallarooMain(env)
