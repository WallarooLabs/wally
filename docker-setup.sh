#!/bin/sh

cd /src/wallaroo
if [ ! -f Dockerfile ]; then
  echo "====== Copying Wallaoo Source Code to Working Directory (/src/wallaroo) ======"
  cp -r /wallaroo-src/* /src/wallaroo
fi
if [ -d /src/python-virtualenv ]; then
  cd /src/python-virtualenv
  if [ ! -f pip-selfcheck.json ]; then
    echo "====== Setting up Persistent Python Virtual Environment ======"
    virtualenv .
    echo "====== Done Setting up Persistent Python Virtual Environment ======"
  fi
  echo "====== Activating Persistent Python Virtual Environment ======"
  echo "====== WARNING: Any software installed via apt-get will not be persistent ======"
  echo "====== WARNING: Please make sure to use pip/easy_install instead ======"
  . bin/activate
fi
cd /src
exec bash

