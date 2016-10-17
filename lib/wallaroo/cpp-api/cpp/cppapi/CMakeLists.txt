#
# KAGR (kevin@sendence.com)
#
cmake_minimum_required(VERSION 3.5)


include (TestBigEndian)
TEST_BIG_ENDIAN(IS_BIG_ENDIAN)
if(IS_BIG_ENDIAN)
    message(STATUS "BIG_ENDIAN")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_BIG_ENDIAN")
else()
    message(STATUS "LITTLE_ENDIAN")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_LITTLE_ENDIAN")
endif()

include(CheckCXXCompilerFlag)
CHECK_CXX_COMPILER_FLAG("-std=c++11" COMPILER_SUPPORTS_CXX11)
if(COMPILER_SUPPORTS_CXX11)
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
	set(CMAKE_CXX_STANDARD 11)
	set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()

set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -O0 -g")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_DEBUG} -DCONSOLE")
message("CMAKE_BUILD_TYPE = ${CMAKE_BUILD_TYPE}")

set(HEADER_FILES
	hpp/Logger.hpp
	hpp/Buffers.hpp
	hpp/ApiHooks.hpp
	hpp/ApiObject.hpp
	hpp/WallarooVersion.hpp
)



set(SOURCE_FILES
	cpp/Logger.cpp
	cpp/Buffer.cpp
	cpp/RawBuffer.cpp
	cpp/ManagedBuffer.cpp
	cpp/ApiHooks.cpp
)

message("Inside sibdir, include dir: ${PROJECT_SOURCE_DIR}/cppapi/hpp")


include_directories("${PROJECT_SOURCE_DIR}/cppapi/hpp")
include_directories("hpp")

# add_executable(testapi ${SOURCE_FILES} cpp/tester.cpp)
add_library(wallaroo SHARED ${SOURCE_FILES})
add_library(wallaroo-static STATIC ${SOURCE_FILES})
set_target_properties(wallaroo-static PROPERTIES OUTPUT_NAME "wallaroo")
set_target_properties(wallaroo-static PROPERTIES PREFIX "lib")

target_include_directories(wallaroo PUBLIC ${PROJECT_SOURCE_DIR}/cppapi/hpp)

include (InstallRequiredSystemLibraries)
set (CPACK_PACKAGE_VERSION_MAJOR "${WallarooCppApi_VERSION_MAJOR}")
set (CPACK_PACKAGE_VERSION_MINOR "${WallarooCppApi_VERSION_MINOR}")

include (CPack)
install(TARGETS wallaroo EXPORT ${PROJECT_NAME} DESTINATION lib/${PROJECT_NAME})
install(TARGETS wallaroo-static EXPORT ${PROJECT_NAME} ARCHIVE DESTINATION lib/${PROJECT_NAME})

#
# for system includes
#
install (DIRECTORY hpp/ DESTINATION include/${PROJECT_NAME} FILES_MATCHING PATTERN "*.hpp")
install (DIRECTORY hpp/ DESTINATION ${PROJECT_BINARY_DIR}/include FILES_MATCHING PATTERN "*.hpp")
#install(EXPORT ${PROJECT_NAME} NAMESPACE ${PROJECT_NAME} DESTINATION lib/${PROJECT_NAME})
