#!/bin/bash

clang++ -g -Wall -std=c++11 -stdlib=libc++ -mmacosx-version-min=10.8 -o build/arizona.o -I"hpp" -I"/usr/local/include/" -c cpp/Arizona.cpp; rm build/libarizona-source-app.a ; ar rvs build/libarizona-source-app.a build/arizona.o

~/git/ponyc/build/debug/ponyc --debug --path=/Users/nitbix/git/buffy-cpp-api/lib:/usr/local/lib/WallarooCppApi/:/Users/nitbix/git/buffy-cpp-api/apps/arizona-source-app/build/ --output=build arizona-source-app/
