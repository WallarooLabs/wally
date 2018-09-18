#!/bin/sh

. ./COMMON.sh

echo Test SSH
for i in $SERVER1_EXT $SERVER2_EXT $SERVER3_EXT $SERVER4_EXT; do
    echo Check $i
    ssh -n $USER@$i "whoami"
    echo
done

echo Curl step
for i in $SERVER1_EXT $SERVER2_EXT $SERVER3_EXT $SERVER4_EXT; do
    ssh -n $USER@$i "curl https://raw.githubusercontent.com/WallarooLabs/wallaroo/0.5.2/misc/wallaroo-up.sh -o /tmp/wallaroo-up.sh -J -L" &
done
wait

echo Install step
for i in $SERVER1_EXT $SERVER2_EXT $SERVER3_EXT $SERVER4_EXT; do
    ssh -n $USER@$i "yes | bash /tmp/wallaroo-up.sh -t python" &
done
wait

echo Check the install step
for i in $SERVER1_EXT $SERVER2_EXT $SERVER3_EXT $SERVER4_EXT; do
    echo Check $i
    ssh -n $USER@$i "tail ~/wallaroo-up.log"
    echo
done
