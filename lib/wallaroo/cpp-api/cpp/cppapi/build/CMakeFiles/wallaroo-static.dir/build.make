# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 3.5

# Delete rule output on recipe failure.
.DELETE_ON_ERROR:


#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:


# Remove some rules from gmake that .SUFFIXES does not remove.
SUFFIXES =

.SUFFIXES: .hpux_make_needs_suffix_list


# Suppress display of executed commands.
$(VERBOSE).SILENT:


# A target that is always out of date.
cmake_force:

.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

# The shell in which to execute make rules.
SHELL = /bin/sh

# The CMake executable.
CMAKE_COMMAND = /usr/bin/cmake

# The command to remove a file.
RM = /usr/bin/cmake -E remove -f

# Escaping for special characters.
EQUALS = =

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/build

# Include any dependencies generated for this target.
include CMakeFiles/wallaroo-static.dir/depend.make

# Include the progress variables for this target.
include CMakeFiles/wallaroo-static.dir/progress.make

# Include the compile flags for this target's objects.
include CMakeFiles/wallaroo-static.dir/flags.make

CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.o: CMakeFiles/wallaroo-static.dir/flags.make
CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.o: ../cpp/Logger.cpp
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_1) "Building CXX object CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.o"
	/usr/bin/c++   $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.o -c /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/Logger.cpp

CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.i"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/Logger.cpp > CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.i

CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.s"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/Logger.cpp -o CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.s

CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.o.requires:

.PHONY : CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.o.requires

CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.o.provides: CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.o.requires
	$(MAKE) -f CMakeFiles/wallaroo-static.dir/build.make CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.o.provides.build
.PHONY : CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.o.provides

CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.o.provides.build: CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.o


CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.o: CMakeFiles/wallaroo-static.dir/flags.make
CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.o: ../cpp/Buffer.cpp
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_2) "Building CXX object CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.o"
	/usr/bin/c++   $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.o -c /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/Buffer.cpp

CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.i"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/Buffer.cpp > CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.i

CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.s"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/Buffer.cpp -o CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.s

CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.o.requires:

.PHONY : CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.o.requires

CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.o.provides: CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.o.requires
	$(MAKE) -f CMakeFiles/wallaroo-static.dir/build.make CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.o.provides.build
.PHONY : CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.o.provides

CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.o.provides.build: CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.o


CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.o: CMakeFiles/wallaroo-static.dir/flags.make
CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.o: ../cpp/RawBuffer.cpp
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_3) "Building CXX object CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.o"
	/usr/bin/c++   $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.o -c /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/RawBuffer.cpp

CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.i"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/RawBuffer.cpp > CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.i

CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.s"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/RawBuffer.cpp -o CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.s

CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.o.requires:

.PHONY : CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.o.requires

CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.o.provides: CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.o.requires
	$(MAKE) -f CMakeFiles/wallaroo-static.dir/build.make CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.o.provides.build
.PHONY : CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.o.provides

CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.o.provides.build: CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.o


CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.o: CMakeFiles/wallaroo-static.dir/flags.make
CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.o: ../cpp/ManagedBuffer.cpp
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_4) "Building CXX object CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.o"
	/usr/bin/c++   $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.o -c /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/ManagedBuffer.cpp

CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.i"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/ManagedBuffer.cpp > CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.i

CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.s"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/ManagedBuffer.cpp -o CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.s

CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.o.requires:

.PHONY : CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.o.requires

CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.o.provides: CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.o.requires
	$(MAKE) -f CMakeFiles/wallaroo-static.dir/build.make CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.o.provides.build
.PHONY : CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.o.provides

CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.o.provides.build: CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.o


CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.o: CMakeFiles/wallaroo-static.dir/flags.make
CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.o: ../cpp/ManagedObject.cpp
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_5) "Building CXX object CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.o"
	/usr/bin/c++   $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.o -c /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/ManagedObject.cpp

CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.i"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/ManagedObject.cpp > CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.i

CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.s"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/ManagedObject.cpp -o CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.s

CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.o.requires:

.PHONY : CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.o.requires

CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.o.provides: CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.o.requires
	$(MAKE) -f CMakeFiles/wallaroo-static.dir/build.make CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.o.provides.build
.PHONY : CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.o.provides

CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.o.provides.build: CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.o


CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.o: CMakeFiles/wallaroo-static.dir/flags.make
CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.o: ../cpp/Data.cpp
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_6) "Building CXX object CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.o"
	/usr/bin/c++   $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.o -c /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/Data.cpp

CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.i"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/Data.cpp > CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.i

CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.s"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/Data.cpp -o CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.s

CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.o.requires:

.PHONY : CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.o.requires

CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.o.provides: CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.o.requires
	$(MAKE) -f CMakeFiles/wallaroo-static.dir/build.make CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.o.provides.build
.PHONY : CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.o.provides

CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.o.provides.build: CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.o


CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.o: CMakeFiles/wallaroo-static.dir/flags.make
CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.o: ../cpp/ApiHooks.cpp
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_7) "Building CXX object CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.o"
	/usr/bin/c++   $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.o -c /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/ApiHooks.cpp

CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.i"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/ApiHooks.cpp > CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.i

CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.s"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/ApiHooks.cpp -o CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.s

CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.o.requires:

.PHONY : CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.o.requires

CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.o.provides: CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.o.requires
	$(MAKE) -f CMakeFiles/wallaroo-static.dir/build.make CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.o.provides.build
.PHONY : CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.o.provides

CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.o.provides.build: CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.o


CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.o: CMakeFiles/wallaroo-static.dir/flags.make
CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.o: ../cpp/Hashable.cpp
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --progress-dir=/home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_8) "Building CXX object CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.o"
	/usr/bin/c++   $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.o -c /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/Hashable.cpp

CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.i: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Preprocessing CXX source to CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.i"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -E /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/Hashable.cpp > CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.i

CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.s: cmake_force
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green "Compiling CXX source to assembly CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.s"
	/usr/bin/c++  $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -S /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/cpp/Hashable.cpp -o CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.s

CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.o.requires:

.PHONY : CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.o.requires

CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.o.provides: CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.o.requires
	$(MAKE) -f CMakeFiles/wallaroo-static.dir/build.make CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.o.provides.build
.PHONY : CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.o.provides

CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.o.provides.build: CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.o


# Object files for target wallaroo-static
wallaroo__static_OBJECTS = \
"CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.o" \
"CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.o" \
"CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.o" \
"CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.o" \
"CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.o" \
"CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.o" \
"CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.o" \
"CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.o"

# External object files for target wallaroo-static
wallaroo__static_EXTERNAL_OBJECTS =

build/lib/libwallaroo.a: CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.o
build/lib/libwallaroo.a: CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.o
build/lib/libwallaroo.a: CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.o
build/lib/libwallaroo.a: CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.o
build/lib/libwallaroo.a: CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.o
build/lib/libwallaroo.a: CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.o
build/lib/libwallaroo.a: CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.o
build/lib/libwallaroo.a: CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.o
build/lib/libwallaroo.a: CMakeFiles/wallaroo-static.dir/build.make
build/lib/libwallaroo.a: CMakeFiles/wallaroo-static.dir/link.txt
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --green --bold --progress-dir=/home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/build/CMakeFiles --progress-num=$(CMAKE_PROGRESS_9) "Linking CXX static library build/lib/libwallaroo.a"
	$(CMAKE_COMMAND) -P CMakeFiles/wallaroo-static.dir/cmake_clean_target.cmake
	$(CMAKE_COMMAND) -E cmake_link_script CMakeFiles/wallaroo-static.dir/link.txt --verbose=$(VERBOSE)

# Rule to build all files generated by this target.
CMakeFiles/wallaroo-static.dir/build: build/lib/libwallaroo.a

.PHONY : CMakeFiles/wallaroo-static.dir/build

CMakeFiles/wallaroo-static.dir/requires: CMakeFiles/wallaroo-static.dir/cpp/Logger.cpp.o.requires
CMakeFiles/wallaroo-static.dir/requires: CMakeFiles/wallaroo-static.dir/cpp/Buffer.cpp.o.requires
CMakeFiles/wallaroo-static.dir/requires: CMakeFiles/wallaroo-static.dir/cpp/RawBuffer.cpp.o.requires
CMakeFiles/wallaroo-static.dir/requires: CMakeFiles/wallaroo-static.dir/cpp/ManagedBuffer.cpp.o.requires
CMakeFiles/wallaroo-static.dir/requires: CMakeFiles/wallaroo-static.dir/cpp/ManagedObject.cpp.o.requires
CMakeFiles/wallaroo-static.dir/requires: CMakeFiles/wallaroo-static.dir/cpp/Data.cpp.o.requires
CMakeFiles/wallaroo-static.dir/requires: CMakeFiles/wallaroo-static.dir/cpp/ApiHooks.cpp.o.requires
CMakeFiles/wallaroo-static.dir/requires: CMakeFiles/wallaroo-static.dir/cpp/Hashable.cpp.o.requires

.PHONY : CMakeFiles/wallaroo-static.dir/requires

CMakeFiles/wallaroo-static.dir/clean:
	$(CMAKE_COMMAND) -P CMakeFiles/wallaroo-static.dir/cmake_clean.cmake
.PHONY : CMakeFiles/wallaroo-static.dir/clean

CMakeFiles/wallaroo-static.dir/depend:
	cd /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/build && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/build /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/build /home/nisan/proj/sendence/Buffy/lib/wallaroo/cpp-api/cpp/cppapi/build/CMakeFiles/wallaroo-static.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : CMakeFiles/wallaroo-static.dir/depend

