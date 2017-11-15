# Tips for using Wallaroo in Docker

In this section, we will cover some tips that can help faciliate the development process for users of the Wallaroo Docker image.

## Editing Wallaroo files within the Wallaroo Docker container

When we start the Wallaroo Docker image with the `-v /tmp/wallaroo-docker/wallaroo-src:/src/wallaroo` option, as described in the [Run a Wallaroo Application in Docker](/book/getting-started/run-a-wallaroo-application-docker.md) section, we will be creating a new directory locally at `/tmp/wallaroo-docker/wallaroo-src` if it does not exist, which will be populated with the Wallaroo source code when we start the container for the first time. It is to be noted that the Wallaroo Docker image will only copy the source code to an empty directory on the host so it is advised that you use an empty directory the first time you run the `docker run` command. The source code will persist on your machine until you decide to remove it.

Now, you can modify any of the Python example applications, located under `/tmp/wallaroo-docker/wallaroo-src/examples/python`, using the editor of your choice on your machine.

## Installing Python modules in Virtualenv

When we start the Wallaroo Docker image with the `-v /tmp/wallaroo-docker/python-virtualenv:/src/python-virtualenv` option, as described in the [Run a Wallaroo Application in Docker](/book/getting-started/run-a-wallaroo-application-docker.md) section, we will be creating a new directory locally at `/tmp/wallaroo-docker/python-virtualenv` if it does not exist, which will create a persistent Python `virtualenv` directory on your machine.

Now, anytime you enter the Wallaroo Docker image with the `bash docker exec -it wally environment-setup.sh` command, you will automatically be in the Wallaroo `virtualenv` and can install modules using `pip install` or `easy_install`. These modules will persist even if you exit the container and re enter as long as you start with the same mount options for the `virtualenv` directory. It is to be noted that any modules that are installed via `apt-get` will not persist beyond the lifecycle of the container.
