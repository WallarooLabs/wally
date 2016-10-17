#
# KAGR (kevin@sendence.com)
#
cmake_minimum_required(VERSION 3.5)

project(WallarooCppApi)
set(WallarooCppApi_VERSION_MAJOR 0)
set(WallarooCppApi_VERSION_MINOR 81)
set(PROJECT_DIR "${CMAKE_BINARY_DIR}")
set(PROJECT_SOURCE_DIR "${PROJECT_DIR}/cpp")
set(PROJECT_BINARY_DIR "${PROJECT_DIR}/build")
set(EXECUTABLE_OUTPUT_PATH "${PROJECT_BINARY_DIR}/bin")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib")
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib")


include(CheckCXXCompilerFlag)
CHECK_CXX_COMPILER_FLAG("-std=c++11" COMPILER_SUPPORTS_CXX11)
if(COMPILER_SUPPORTS_CXX11)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
    set(CMAKE_CXX_STANDARD 11)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()


include (TestBigEndian)
TEST_BIG_ENDIAN(IS_BIG_ENDIAN)
if(IS_BIG_ENDIAN)
    message(STATUS "BIG_ENDIAN")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_BIG_ENDIAN")
else()
    message(STATUS "LITTLE_ENDIAN")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_LITTLE_ENDIAN")
endif()


set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -O0")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_DEBUG} -DCONSOLE")
message("CMAKE_BUILD_TYPE = ${CMAKE_BUILD_TYPE}")

set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_LD_FLAGS} -execute -dead_strip -lponyrt -lSystem")
set(POSITION_INDEPENDENT_CODE ON)
set(BUILD_SHARED_LIBS ON)



set(GENERATED_VERSION_FILE "${PROJECT_BINARY_DIR}/WallarooVersion.hpp")
set(GENERATED_VERSION_FILE "${PROJECT_SOURCE_DIR}/cppapi/hpp/WallarooVersion.hpp")
configure_file (
       "${PROJECT_SOURCE_DIR}/cppapi/hpp/WallarooVersion.hpp.in"
        "${GENERATED_VERSION_FILE}"
)


message("add_subdir(${PROJECT_SOURCE_DIR}/cppapi)")
include_directories(${PROJECT_SOURCE_DIR})
include_directories(${PROJECT_SOURCE_DIR}/cppapi/hpp)
add_subdirectory("${PROJECT_SOURCE_DIR}/cppapi")

#
# still missinc pkg-config install
#
export(PACKAGE "${PROJECT_NAME}")

