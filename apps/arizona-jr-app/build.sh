#!/bin/bash


if [ "$WALLAROO_HOME" == "" ] ; then
    echo "WALLAROO_HOME not set, cannot continue!"
    exit 1
fi


#
# loading up the path for sourcing
#
CC=`type -P c++` 
if [ "$?" -gt 0 ] ; then
    echo "Unable to find compiler, sourcing dev-4" 
    source /opt/rh/devtoolset-4/enable 
    echo `which c++` 
else
    echo "Compiler: $CC" 
fi



#
# arizona
#
mkdir -p build
pushd build
cmake ../
make
popd



#
# wallaroo
#
echo $WALLAROO_HOME
WALL_PATH=$WALLAROO_HOME:../../lib/wallaroo/cpp-api/cpp/cppapi/build/build/lib:./build/lib:/usr/lib
echo "Wallaroo path: $WALL_PATH"
ponyc --debug --path=$WALL_PATH --output=build arizona-jr-app/
cp build/arizona-jr-app ~/dist/bin

