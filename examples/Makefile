UNAME = $(shell uname)
ifeq ($(UNAME), Linux)
LIB_EXT = so
CC ?= gcc
endif

ifeq ($(UNAME), Darwin)
LIB_EXT = dylib
CC ?= clang
endif

SHELL = bash
CXX ?= g++

CXX_FLAGS = -lstdc++ -std=c++11
DEF_PATHS = -I $(HALIDE_PATH)/include
DBG_FLAG = -g

# generated wrapper with method signature and return statement
build/tmp/%_fn.cpp: %.cpp Makefile
	mkdir -p build/tmp
	echo '#include "Halide.h"' > $@
	echo 'using namespace Halide;' >> $@
	echo 'Func getFunction() {' >> $@
	echo 'Func result;' >> $@
	cat $< >> $@
	echo 'return result;' >> $@
	echo '}' >> $@

bin/libHalide.so:
	mkdir -p bin
	cp $(HALIDE_PATH)/bin/libHalide.so bin

build/main.o: main.cpp
	echo $(HALIDE_PATH)
	mkdir -p build
	$(CXX) $(DBG_FLAG) $(CXX_FLAGS) $(DEF_PATHS) -c $< -o $@

# a main function that calls the generated function and writes the .o and .h files
build/tmp/mk_%: build/tmp/%_fn.cpp build/main.o bin/libHalide.so
	echo $(HALIDE_PATH)
	$(CXX) build/main.o $< $(DBG_FLAG) $(DEF_PATHS) $(CXX_FLAGS) -lpthread -Lbin -lHalide -o $@

# call the generated executable to produce the object code
build/%.o: build/tmp/mk_%
	mkdir -p build
	./$< build/$* render

build/error_handler.o: error_handler.c
	mkdir -p build
	$(CC) -c -fPIC $< -o $@

# link the .o file with the pipeline implementation and make it a dylib
build/%.$(LIB_EXT): build/%.o build/error_handler.o
	$(CC) $(DBG_FLAG) -O3 -lpthread build/error_handler.o $< -shared -o $@

build/main.$(LIB_EXT):
	>&2 echo "Cannot build wrapper library for main.cpp"
	exit 2

clean:
	rm -fR build bin
