#!/bin/bash

name=`uname`
if [ "$name" != "Linux" ] ; then
    echo "Not a Linux machine, not copying to different hosts"
    exit 0
fi

echo "Copying to exec server(s).."
hosts=`cat hosts.txt`
for host in $hosts
do
    scp -i ~/.ssh/us-east-1.pem ~/dist/bin/arizona-source-app ec2-user@$host:/apps/dev/arizona/bin/
    scp -i ~/.ssh/us-east-1.pem ~/dist/bin/sender ec2-user@$host:/apps/dev/arizona/bin/
    if [ $? -gt 0 ] ; then
	echo "$host: FAILED"
    else
	echo "$host: Done!"
    fi
done
