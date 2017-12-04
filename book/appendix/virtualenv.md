# Walaroo and Virtualenv

We recommend using [virtualenv](https://virtualenv.pypa.io/en/stable/) to handle your application's dependencies.

While not required to run Wallaroo applications, virtualenv will ensure that your application and development environment are isolated from the rest of your Python installation(s) on your computer. In addition, virtualenv will ensure that Machida uses the correct version of Python if you have multiple versions installed on your computer.

## Installing Virtualenv

Follow the instructions on [the virtualenv website](https://virtualenv.pypa.io/en/stable/installation/).

## Setting up Virtualenv for your Application

To create a virtualenv for your application, run the following command

```bash
virtualenv --python=python2 ENV
```

This will create a directory named `ENV` and set up all of the scripts and dependencies required to run an isolated Python2 virtual environment, located in `ENV`.

## Cleaning up a Virtualenv

To clean up or remove an installed virtualenv, all you need to do is delete the directory you created.

For the `ENV` virtualenv set up above, the following will remove it entirely:

```bash
rm -fr ENV
```

## Using Virtualenv

To use the virtualenv, activate it in your shell. In the bash shell, this command is

```bash
$ source ENV/bin/activate
(env) $
```

If this command does not work for your specific shell, please refer to the [virtualenv userguide](https://virtualenv.pypa.io/en/stable/userguide/#activate-script).


Now, when you run `python` or `pip`, it will be using the ones set up in the virtual environment, and any new packages and dependencies will be installed within the `ENV` path.

To install new modules using pip, run pip within an activated virtualenv:

```bash
(env) $ pip install ujson
```

To exit the virtualenv, use the `deactivate` command.

## Running a Wallaroo Application with Virtualenv

To run a Wallaroo application with virtualenv, run it within an activated shell:

```bash
source ENV/bin/activate
export PYTHONPATH="$HOME/wallaroo-tutorial/wallaroo/machida:$HOME/wallaroo-tutorial/wallaroo/examples/python/celsius"
$HOME/wallaroo-tutorial/wallaroo/machida/build/machida --application-module celsius \
  --in 127.0.0.1:7000 --out 127.0.0.1:5555 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:6000 --data 127.0.0.1:6001 --name worker-name \
  --external 127.0.0.1:5050 --cluster-initializer --ponythreads=1 \
  --ponynoblock
```
