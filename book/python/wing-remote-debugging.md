# Setting up Wing IDE for Remote Debugging a Python Wallaroo Application

In this section of our instructions, we will help you get set up using Wing IDE to remote debug Python Wallaroo applications on Bash/WSL from Windows. If you haven't done so, go through the [Setting up Windows for Remote Debugging using Wing IDE](/book/python/wing-on-windows-remote-debugging-setup.md) instructions to make sure your machine is set up for Windows/Ubuntu communication via ssh. SSH servers should be running on both Windows and Ubuntu. You should also have `pageant` running in Windows and your ssh key should be in `pageant`'s Key List. Although these instructions are Windows and Ubuntu on Bash/WSL specific, a few modifications to them will allow you to do remote debugging of Python Wallaroo applications on any remote host.

## Wing IDE Remote Debugging Setup

Let's get Wing IDE set up for remote debugging. We'll set up a remote host for Bash/WSL so you can use it to remote debug a Python Wallaroo application.

### Create a New Project

First, let's head over to our `reverse` example inside of bash

```bash
cd ~/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/examples/python/reverse
```

We'll want to copy over the `wingdbstub.py` file (created when Wing IDE installed the remote agent in our initial setup in your WINGHOME location) to our current directory.

```bash
cp ~/winghome/wingdbstub.py .
```

Now in Wing, let's start a new project by clicking on `Project -> New Project` and clicking `OK` on the `New Project` gui.

### Add New Remote Host

On the Wing IDE navbar select `Project -> Remote Hosts...`.

![Wing Remote Hosts](/book/python/images/remote-debugging/wing-remote-hosts.png)

Then click on the `+` under the `Manage Remote Hosts` gui.

Under the `General` tab of the `Remote Host: New` gui, we'll want to insert the following information:

Identifier: `machida` or your own unique identifier
Host Name: `<your-ubuntu-user>@<your-PuTTY-saved-session-name>`
WINGHOME: `/home/<your-ubuntu-user>/winghome`
Python Executable: `/usr/bin/python`

**Note:** if using a different Python installation, modify the path provided to `Python Executable` to point to that installation.

Under the `Options` tab we'll want to select the following:

Remote Agent Port: Use specified port: 50010
Remote Debug Ports: Start with this port: 50050

Then select `OK`

Once submitted, Wing will probe the remote host for the remote agent. It will fail and prompt to install it now. Click on `Install Remote Agent`.

After installation is complete Wing will once again probe and show a success prompt with the remote hosts' information.

We've got our remote host set up, now let's set up our project to use this host.

### Remote Host Project Set Up

We'll want to modify our project so it can access our files on the remote host.

Let's modify our projects properties by selecting `Project -> Project Properties`

![Wing Project Properties](/book/python/images/remote-debugging/wing-project-properties.png)

Under Environment for `Python Executable` we'll select the `Remote` radio button and choose the remote host we set up earlier in the drop down. We'll click on `Apply` then `OK`.

On the bottom left-hand corner of your screen verify that `Accept Debug Connections` is checked.

![Wing Accept Debug Connections](/book/python/images/remote-debugging/wing-accept-debug.png)

We now have our project set up, let's run through the `reverse` example.

## Wing Remote Debugging Example

In this section, we'll run through setting up our Reverse example so you can verify that everything works as expected.

### Reverse Example Setup

Now that our project is setup, let's open the `~/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/examples/python/reverse/wingdbstub.py` file via Wing's `File -> Open Remote File`.

We'll modify the `kEmbedded` config from `0` to `1` and save.

![Wing kEmbedded](/book/python/images/remote-debugging/wing-kembedded.png)

We'll also open the `~/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/examples/python/reverse/reverse.py` file via Wing's `File -> Open Remote File`

We'll add `import wingdbstub` in order to use our debugger and we'll also set a breakpoint within our `compute` function on the `print "compute", data` line.

![Wing Remote Debug Reverse](/book/python/images/remote-debugging/wing-reverse-debug.png)

### Reverse Example Debugging

Now that we're setup, let's run our `reverse` example. You can find the instructions [here](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/reverse/README.md).

Once you've successfully run `reverse` via `machida` and sent over messages, we'll see that we've hit our breakpoint and can inspect the `data` variable. If we continue, we'll hit the breakpoint as every new message arrives.

![Wing Reverse Debugging compute](/book/python/images/remote-debugging/wing-reverse-debug-breakpoint.png)

We're all set in getting Wing Remote Debugging setup, you can now follow these steps for every new project you start and need to debug.
