---
title: "Running A Wallaroo Application"
menu:
  toc:
    parent: "ponytutorial"
    weight: 10
toc: true
---
{{% note %}}
You should have already completed the [setup instructions]({{< relref "/pony-installation" >}}) in the "Pony Installation" guide.
{{% /note %}}

## Running the Application

Wallaroo applications are built using the Pony compiler. The compiler will build our application along with any other tools used, optimize it, and link whatever libraries were needed. Once compiled, the application can be run over and over again, independently from the compiler or anything else. It will exist as a complete program on it's own.

Generally, in order to build a Wallaroo Pony application, the following steps should be followed:

* import the Wallaroo library and any other needed packages in the Pony application's `.pony` file
* define the `Main` actor and the `create` function.
* Create classes/primitives that provide the correct Wallaroo Pony interfaces (more on this later)
* Call `Wallaroo.build_application` with the needed arguments in your application's `.pony` file.
* compile the binary using the Pony compiler: `ponyc`.

Once loaded, Wallaroo executes `Wallaroo.build_application`, constructs the appropriate topology, and enters a `ready` state where it awaits incoming data to process.

## A Note about Precompiled Tools

There are a set of tools precompiled for you, to make getting started easier. If you have installed Wallaroo as instructed and follow the [Starting a new shell for Wallaroo](/python-tutorial/starting-a-new-shell/) instructions each time you start a new shell, these tools will be available to you in your PATH.

## Next Steps

To try running an example, go to [the Alerts example application](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/pony/alerts_stateless/) and follow its [instructions](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/pony/alerts_stateless/README.md).

To learn how to write your own Wallaroo Pony application, continue to [Writing Your Own Application](/pony-tutorial/writing-your-own-application/)

To find out more detail on the command line arguments and other aspects of running Wallaroo application, see the [Running Wallaroo](/operators-manual/running-wallaroo/) section.
