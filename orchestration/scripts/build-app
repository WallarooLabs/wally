#!/bin/sh

if [[ -z $1 ]]; then
	echo 'You must provide an app name'
	exit 1
fi

docker run --rm -it -u `id -u` -v /home/ubuntu/buffy:/home/ubuntu/buffy -v ~/.gitconfig:/.gitconfig -w /home/ubuntu/buffy/apps/$1 --entrypoint stable sendence/ponyc:sendence-8.0.0-debug fetch

docker run --rm -it -u `id -u` -v /home/ubuntu/buffy:/home/ubuntu/buffy -w /home/ubuntu/buffy/apps/$1 --entrypoint stable sendence/ponyc:sendence-8.0.0-debug env ponyc  .
