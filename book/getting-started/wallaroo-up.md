# Setting Up Your Wallaroo Development Environment using Wallaroo Up

These instructions have been tested on Ubuntu Bionic/Trusty/Xenial, Fedora 28, CentOS 7, and Debian Stretch releases. They should also work on Ubuntu Artful, Fedora 26/27, Red Hat Enterprise Linux 7, and Debian Jessie/Buster releases.

## Memory requirements

In order to compile the Wallaroo example applications, your system will need to have approximately 3 GB working memory (this can be RAM or swap). If you don't have enough memory, you are likely to see that the compile process is `Killed` by the OS.

## Download Wallaroo Up script

```bash
cd /tmp
curl https://raw.githubusercontent.com/WallarooLabs/wallaroo/{{ book.wallaroo_version }}/misc/wallaroo-up.sh -o wallaroo-up.sh -J -L
chmod +x wallaroo-up.sh
```

## Run the Wallaroo Up script

The `-t python` argument is required for a Python environment installation. The `-p <PATH>` argument is optional and can be used to control where the Wallaroo tutorial is installed into (the default is `~/wallaroo-tutorial/wallaroo`).

The script will require superuser privileges via `sudo` and will throw an error if `sudo` is not available. The script will prompt you prior to making any changes. It can optionally print out the commands it will run.

```bash
./wallaroo-up.sh -t python 
```

Follow the prompts to have Wallaroo Up install and configure Wallaroo and its dependencies.

Once Wallaroo Up has finished installing and configuring Wallaroo for your environment, it will also create an `activate` script that can be used to set up the appropriate environment variables.

## Register

Register today and receive a Wallaroo T-shirt and a one-hour phone consultation with Sean, our V.P. of Engineering, to discuss your streaming data questions. Not sure if you have a streaming data problem? Not sure how to go about architecting a streaming data system? Looking to improve an existing system? Not sure how Wallaroo can help? Sean has extensive experience and is happy to help you work through your questions.

Please register here: [https://www.wallaroolabs.com/register](https://www.wallaroolabs.com/register).

Your email address will only be used to facilitate the above.

## Conclusion

Awesome! All set. Time to try running your first application.
