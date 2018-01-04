# Starting a Wallaroo Go Project

There are a few things that need to be done in order to start a Wallaroo Go project.

## Create an Application Directory

The application should live in its own directory. You can create the directory anywhere.

## Copy the `application.pony` File to the Application Directory

A Wallaroo Go application is a Pony program that uses Go objects and functions to do work. The `application.pony` file contains code that sets up the Pony program and calls various pieces of Go and Wallaroo code to set up the application.

`application.pony` is found in the Wallaroo repo in the directory `wallaroo/go_api/application-template/`. You should copy this file into the root of your project directory.

You will not need to modify this file at all if you follow these instructions for laying out your project.

## Create a `bundle.json` File for `stable`

`stable` is a tool for managing Pony dependencies and building Pony projects. `stable` reads a file called `bundle.json` to figure out where to find dependencies. This file can be created using `stable add ...` to add the dependencies. You should run these commands in the project directory so that the `bundle.json` file will be created there.

The easiest thing to do would be to create a shell variable that contains the path to where you have cloned the wallaroo repo. For example, if it is your home directory then your shell variable would be set with

```bash
WALLAROO_HOME=$HOME/wallaroo
```

Once you've done that, you can run the following commands to create the `bundle.json` file:

```bash
stable add local $WALLAROO_HOME/lib
stable add local $WALLAROO_HOME/go_api/pony
stable add github WallarooLabs/pony-kafka --tag=0.3.0
stable add local lib
```

The contents of the `bundle.json` file will look something like this:

```json
{
    "deps": [
        {
            "type": "local",
            "local-path": "/Users/aturley/wallaroo/lib"
        },
        {
            "type": "local",
            "local-path": "/Users/aturley/wallaroo/go_api/pony"
        },
        {
            "type": "github",
            "repo": "WallarooLabs/pony-kafka",
            "tag": "0.3.0"
        },
        {
            "type": "local",
            "local-path": "lib"
        }
    ]
}
```

After you've created the `bundle.json` file, you should fetch the dependencies:

```bash
stable fetch
```

## Create a `go` Workspace

Within your project directory you should create a directory hierarchy that looks like this:

```
go
+--src
   +--PROJECT_NAME
```

`PROJECT_NAME` should be the name of your project. You can do this with a command like:

```bash
mkdir -p go/src/PROJECT_NAME
```

## Create a Wallaroo Go Application

The code for your application should be under the `go/src/PROJECT_NAME` directory that you created. There must be a `main` package with an empty `main()` function, and your program must export a C function called `ApplicationSetup`. You must also set the `wallarooapi.Serialize` and `wallarooapi.Deserialize` variables. Here's an outline of what the application file might look like:

```go
package main

import (
	"C"
	wa "wallarooapi"
    // other imports
    // ...
)

//export ApplicationSetup
func ApplicationSetup() *C.char {
	wa.Serialize = Serialize
	wa.Deserialize = Deserialize
    // create the application pipelines
    // ...
	json := application.ToJson()
	return C.CString(json)
}

// define the application classes
// ..

func Serialize(c interface{}) []byte {
    // define your serialization strategy
    // ...
}

func Deserialize(buff []byte) interface{} {
    // define your deserialization strategy
    // ..
}

func main() {}
```

## Build Your Application

### Set Up `GOPATH`

The `GOPATH` must refer to the workspaces that contain both your application code and the Go API code. If you created a `WALLAROO_HOME` variable earlier, you can use it to set your `GOPATH` by running this command in your project directory:

```bash
export GOPATH=${WALLAROO_HOME}/go_api/go:$(pwd)/go
```

The first part of the `GOPATH` points to the Wallaroo Go API workspace, and the second part points to your project's workspace.

### Build the Go Application as a Library

Use the Go compiler to build the Go code as a library archive:

```bash
go build -buildmode=c-archive -o lib/libwallaroo.a PROJECT_NAME
```

This will place the library in a directory called `lib`.

### Build the Wallaroo Application

Use `stable` to invoke the Pony compiler so that it uses the imported libraries:

```bash
stable env ponyc
```

Once you've done this, you will have an executable with the same name as the project directory. This is your Wallaroo application.
