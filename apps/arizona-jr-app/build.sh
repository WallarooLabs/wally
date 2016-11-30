#!/bin/bash


if [ "$WALLAROO_HOME" == "" ] ; then
    echo "WALLAROO_HOME not set, cannot continue!"
    exit 1
fi


#
# arizona
#
#mkdir -p build
g++ -Wall -std=c++11 -o build/libarizona-jr-app.o -I"hpp" -I"../../lib/wallaroo/cpp-api/cpp/cppapi/" -c cpp/Arizona.cpp && rm build/libarizona-jr-app.a ; ar rvs build/libarizona-jr-app.a build/libarizona-jr-app.o



#
# wallaroo
#
echo $WALLAROO_HOME
WALL_PATH=/usr/lib:./build:$WALLAROO_HOME:../../lib/wallaroo/cpp-api/cpp/cppapi/build/build/lib 
echo "Wallaroo path: $WALL_PATH"
ponyc --debug --path=$WALL_PATH --output=build arizona-jr-app/
