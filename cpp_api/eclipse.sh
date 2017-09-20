#!/bin/bash
if [ $# -gt 0 ] ; then
    echo "     use this script to generate eclipse project tools"
    echo "     to import the project, follow these instructions:"
    echo "     https://cmake.org/Wiki/CMake_Generator_Specific_Information"
    exit 1
fi

# cmake -G"Eclipse CDT4 - Unix Makefiles" -D CMAKE_BUILD_TYPE=Debug `pwd`
