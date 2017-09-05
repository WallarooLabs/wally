/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

// the configure options and settings
#define Wallaroo_VERSION_MAJOR 0
#define Wallaroo_VERSION_MINOR 81

#define CXX_MAKE_FLAGS " -std=c++11 -D_LITTLE_ENDIAN -g -O0 -DCONSOLE"
#define CMAKE_SHARED_LINKER_FLAGS " -execute -dead_strip -lponyrt -lSystem"

