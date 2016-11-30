#
# KAGR (kevin@sendence.com)
#
cmake_minimum_required(VERSION 3.5)
set(CMAKE_DISABLE_IN_SOURCE_BUILD ON)
project(arizona-jr-app CXX)
set(CMAKE_VERBOSE_MAKEFILE OFF)
set(CMAKE_COLOR_MAKEFILE   OFF)



#
# project structure
#
set(SUPER_PROJECT "arizona")
set(PROJECT_DIR "${CMAKE_BINARY_DIR}")
set(EXECUTABLE_OUTPUT_PATH "${PROJECT_BINARY_DIR}/bin")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib")
include_directories("${PROJECT_SOURCE_DIR}/hpp")
message("Iclude dir: ${PROJECT_SOURCE_DIR}/hpp")


#
# cxx 11
#
include(CheckCXXCompilerFlag)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
CHECK_CXX_COMPILER_FLAG("-std=c++11" COMPILER_SUPPORTS_CXX11)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
set(CMAKE_CXX_STANDARD 11)


#
# additional compiler flags
#
#set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -O0 -pg")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -O0")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_DEBUG}")
message("CMAKE_BUILD_TYPE = ${CMAKE_BUILD_TYPE}")


#
# source files
#
set(
    HEADER_FILES
    hpp/Arizona.hpp
)

set(
    CFG_GEN_SOURCE_FILES
    cpp/Arizona.cpp
)


#
# wallaroo additions
#
link_directories(../../lib/wallaroo/cpp-api/cpp/cppapi/build/build/lib)
message("added link dir ../../lib/wallaroo/cpp-api/cpp/cppapi/build/build/lib")



# arizona-jr-app
# the arizona-jr-app and libs it needs
#
add_library(arizona-jr-app STATIC ${CFG_GEN_SOURCE_FILES})
target_link_libraries(arizona-jr-app wallaroo)
set_target_properties(arizona-jr-app PROPERTIES OUTPUT_NAME "arizona-jr-app")
set_target_properties(arizona-jr-app PROPERTIES PREFIX "lib")



#
# installations
#
include(CPack)
install(TARGETS arizona-jr-app EXPORT ${PROJECT_NAME} DESTINATION bin/${SUPER_PROJECT}/${PROJECT_NAME})
