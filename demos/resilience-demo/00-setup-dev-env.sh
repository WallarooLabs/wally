#!/bin/sh

. ./COMMON.sh

if [ $SERVER1_EXT = 127.0.0.1 -o $SERVER1_EXT = localhost ]; then
	SERVERS_EXT=$SERVER1_EXT
else
	SERVERS_EXT="$SERVER1_EXT $SERVER2_EXT $SERVER3_EXT $SERVER4_EXT"
fi

echo Test SSH
for i in $SERVERS_EXT; do
    echo Check $i
    ssh -n $USER@$i "whoami"
    echo
done

echo Curl step
for i in $SERVERS_EXT; do
    ssh -n $USER@$i "curl https://raw.githubusercontent.com/WallarooLabs/wallaroo/0.6.1/misc/wallaroo-up.sh -o /tmp/wallaroo-up.sh -J -L" &
done
wait

echo Install step
for i in $SERVERS_EXT; do
    ssh -n $USER@$i "yes | bash /tmp/wallaroo-up.sh -t python" &
done
wait

echo Check the install step
for i in $SERVERS_EXT; do
    echo Check $i
    ssh -n $USER@$i "tail ~/wallaroo-up.log"
    echo
done
