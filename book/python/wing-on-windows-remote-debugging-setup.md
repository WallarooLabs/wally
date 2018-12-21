# Setting up Windows for Remote Debugging using Wing IDE

We understand that as a Windows Developer, you may have the preference to do your development on Windows instead of on Linux. To encourage you to do so, we're providing this guide to help you set up Windows and Ubuntu for remote debugging. This portion of the instructions will help you get the initial set up done so you can use Wing IDE for remote debugging.

We've tested these instructions with Windows 10 Pro version 1607 build 14393.x and version 1703 build 15063.x with Wing Pro 6 IDE. We assume that you've gone through the setup process for [Windows](/book/getting-started/windows-setup.md) and the Python [building](/book/python/building.md) section. By this point, you should've been able to successfully build and run a Python Wallaroo example application.

Before you can start remote debugging using Wing, there are a few one time set up/installation steps that need to occur on Windows and Ubuntu.

## Initial Setup

Let's get started on setting up Windows and Ubuntu to communicate via ssh.

### Windows Setup

On the Windows side we'll need an ssh server and client so we can communicate with Ubuntu. We've found the SSH Server provided by Windows works great and will use PuTTY as our client. PuTTY also comes with a few additional tools to make communication via ssh easier. We'll be installing and setting those up as well.

#### Run the Windows SSH Server

The first thing you'll need is an ssh server on your Windows machine. As of Windows 10 Pro build 14352, an ssh server is provided if you're running in Developer Mode and it is automatically turned on. Here are the official Windows documents for enabling [developer mode](https://docs.microsoft.com/en-us/windows/uwp/get-started/enable-your-device-for-development).

If you'd prefer to use Windows port of OpenSSH, follow these install [instructions](https://github.com/PowerShell/Win32-OpenSSH/wiki/Install-Win32-OpenSSH).

Verify that the Windows SSH server is up by finding `SshServer` and `SshProxy` under `Services` in Task Manager. If using another SSH server, verify with that server's documentation.

Now that we have our ssh server set up, let's install our ssh client.

#### Install PuTTY

PuTTY is an open source ssh client for Windows and provides a few tools that will make our setup easier. You can find [instructions](http://www.putty.org/) for installing PuTTY on the official PuTTY website. You will need PuTTY, Pageant, and PuTTYgen.

#### Generate SSH Keys

We'll be generating ssh keys so Wing can use them to ssh into our Ubuntu set up without having to provide a password each time.

Open up `PuTTYgen` by going to

```
Windows Start Menu -> P -> PuTTY  (64-bit) -> PuTTYgen
```

![PuTTYgen gui](/book/python/images/remote-debugging/puttygen-generate.png)

Once you're on the PuTTYgen gui, verify that `RSA` is the type of key selected before generating.

Click on `Generate` to generate a public/private key pair.

Once generated, you'll want to copy the contents of `Public key for pasting into OpenSSH authorized_keys file` into `$HOME\Documents\ssh_keys\id_rsa.pub`. You'll also want to click on `Save private key` and save it as `id_rsa.ppk` in `$HOME\Documents\ssh_keys`

We won't need our ssh keys just yet, we'll come back to them once we set up ssh on Ubuntu.

### Ubuntu Setup

We've set up ssh on Windows, now it's time to set it up on Ubuntu. Remember that all commands in this section should be run in `bash` via command prompt or PowerShell.

#### Install OpenSSH

The ssh server we'll be running on Ubuntu is OpenSSH. It's officially supported by Ubuntu and there's plenty of documentation out there in case you run into trouble or need to configure things to your needs.

To install run the following:

```bash
sudo apt-get install openssh-server
```

#### Open SSH Setup

Now that we've installed OpenSSH, let's do some configuration set up so it will work with our Windows client and Wing IDE.

##### Modify sshd config

Open `/etc/ssh/sshd_config` and modify the following config options:

**UsePrivilegeSeparation**
Modify `UsePrivilegeSeparation yes` to `UsePrivilegeSeparation no`

**AuthorizedKeysFile**
Uncomment the `AuthorizedKeysFile     %h/.ssh/authorized_keys` line.

**Port**
If you are running your Windows server on port 22, you will need to run the OpenSSH server on a different port.

Modify `Port 22` to `Port 2200` or your desired port.

Once you have modified the above, exit and save your updated `/etc/ssh/sshd_config` file.

If there are other options you need to change, visit the official `sshd_config` [documentation](http://man.openbsd.org/sshd_config) for a list of options.

##### Generate host keys

We'll need host keys in order to start up the ssh server, let's run the following to generate:

```bash
ssh-keygen -A
```

For more information on what keys are generated or if you want to generate specific keys visit the official [documentation](http://man.openbsd.org/ssh-keygen) for `ssh-keygen`

##### Add Your Authorized Key

Now that we've gotten installation and configuration out of the way, we'll want to add our public ssh key generated before via PuTTY to our `authorized_keys` file. Doing so will allow us to ssh from Windows to Ubuntu without the need of a password on every attempt.

In a `bash` shell, run the following to add your public key to your authorized keys (replace the path with the location of your public key if needed) :

```bash
cat /mnt/c/Users/user/Documents/ssh_keys/id_rsa.pub >> ~/.ssh/authorized_keys
```

We should now be able to use our private key to ssh from Windows into Ubuntu. Let's start our ssh server.

#### Start SSH Server

`sudo service ssh start`

You should see the following output if your ssh server started correctly:

```bash
* Starting OpenBSD Secure Shell server sshd            [ OK ]
```

**Note:** If you installed `openssh` via the repository as indicated above, the ssh service will be started automatically on every boot.

### Verifying SSH Communication

Now that we have our SSH servers set up both on Windows and Ubuntu, let's verify that they can communicate. We'll be doing some additional set up of PuTTY's client tools to make our communication process easier.

#### Pageant Setup

Pageant is an ssh authentication agent, which will hold onto our ssh keys and allow us to ssh to a server without entering a passphrase each time (if necessary).

Start up `Pageant` by opening it via `Windows Start Menu -> PuTTY (64-bit) -> Pageant`. You should now see Pageant in your system tray.

##### Add SSH Key

We'll need to add our ssh key so it can be used by our PuTTY client automatically.

In the system tray right click on `Pageant` and click `Add Key`.

![Pageant key list](/book/python/images/remote-debugging/pageant-key-list.png)

Once the `Pageant Key List` gui pops up, click on the `Add Key` button, navigate to the private key we generated before under `$HOME\Documents\ssh_keys`, select it, and click on `Open`.

Once your ssh key is added, close the `Pageant Key List` gui.

Now let's create an ssh session in PuTTY so that it can be used later by our remote debugger.

#### SSH Session Setup

We'll create a saved ssh session in PuTTY via Pageant in order to take advantage of Pageant's authentication agent and to allow a remote debugger to use PuTTY as the ssh client.

Once again right click on `Pageant` in the system tray and select `New Session`

##### PuTTY Configuration

![PuTTY Config](/book/python/images/remote-debugging/putty-config-session.png)

We'll use the `PuTTY Configuration` gui to create a saved session to be used by Wing IDE. On the left-hand sign of the gui, select `Session`

Under `Basic options for your PuTTY session` we will modify the following:

Host Name (or  IP address): `<your-ubuntu-user>@localhost`

Port: `2200`
* or whatever you entered into /etc/ssh/sshd_config under `Port`

Connection type: `SSH`

Saved Sessions: `name for this session`

##### Auth Setup

on the left-hand side of the gui, Under `Connection` click on the `+` next to `SSH` and click on `Auth`.

![PuTTY config auth](/book/python/images/remote-debugging/putty-config-session-ssh-auth.png)

Under `Authentication parameters` you will see `Private key file for authentication`. Click on the `Browse` button directly below and select the private key we saved before at `$HOME\Documents\ssh_keys\id_rsa.ppk`

Once you're done with the configuration return to the `Session` window and click on the `Save` button to save our session.

After saving our session, we'll verify it works by clicking on `Open`. If successful, you'll be in a shell session on Bash/WSL.

### Successful Communication

We've now successfully set up ssh communication between Windows and Ubuntu. We've also taken a few additional steps in order to make getting started with remote debugging in Wing a bit easier.

In the next [section](/book/python/wing-remote-debugging.md) we'll cover debugging an example application using Wing's remote debugger.
