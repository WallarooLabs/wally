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

### Import Errors when Loading your Application

If you have more than one Python version installed, virtualenv may set up the import paths incorrectly, or an alias may result in the wrong Python version being run. In that case, you may encounter errors such as

```python
Traceback (most recent call last):
  File "wallaroo-{{ book.wallaroo_version }}/examples/python/celsius/celsius.py", line 18, in <module>
    import wallaroo
  File "wallaroo-{{ book.wallaroo_version }}/machida/wallaroo.py", line 16, in <module>
    import argparse
  File "/usr/local/Cellar/python/2.7.14/Frameworks/Python.framework/Versions/2.7/lib/python2.7/argparse.py", line 86, in <module>
    import copy as _copy
  File "/usr/local/Cellar/python/2.7.14/Frameworks/Python.framework/Versions/2.7/lib/python2.7/copy.py", line 52, in <module>
    import weakref
  File "/usr/local/Cellar/python/2.7.14/Frameworks/Python.framework/Versions/2.7/lib/python2.7/weakref.py", line 14, in <module>
    from _weakref import (
ImportError: cannot import name _remove_dead_weakref
Could not load module 'celsius'
```

In order to work correctly, virtualenv needs to be set up with the correct Python path. To do this, use `which` to get the absolute path of your intended Python version:

```bash
virtualenv --python=`which python` ENV
```

If you use a different Python, such as `python2` or `python2.7`, then substitute that into the `which` command:

```bash
virtualenv --python=`which python2.7` ENV
```

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
export PYTHONPATH="$HOME/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/machida:$HOME/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/examples/python/celsius"
$HOME/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/machida/build/machida --application-module celsius \
  --in 127.0.0.1:7000 --out 127.0.0.1:5555 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:6000 --data 127.0.0.1:6001 --name worker-name \
  --external 127.0.0.1:5050 --cluster-initializer --ponythreads=1 \
  --ponynoblock
```

Please be aware that you'll still need to setup a source and sink as well. We include a toolkit named Giles to assist in this. To learn more you can look at [Giles Receiver](/book/wallaroo-tools/giles-receiver.md) and [Giles Sender](/book/wallaroo-tools/giles-sender.md) for more detailed instructions on building and running Giles.

To run a sink for our example with Giles, run

```bash
$HOME/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/giles/receiver/receiver --listen 127.0.0.1:5555 --ponythreads=1 --ponynoblock
```

or if you prefer to log the output into a file, you may use the netcat utility like so

```bash
nc -l 127.0.0.1 5555 > output
```

The contents of your pipeline's decoder will be added to a file named output in the directory from which this is run.
