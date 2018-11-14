# Walaroo and Virtualenv

We recommend using [virtualenv](https://virtualenv.pypa.io/en/stable/) to handle your application's dependencies.

While not required to run Wallaroo applications, virtualenv will ensure that your application and development environment are isolated from the rest of your Python installation(s) on your computer. In addition, virtualenv will ensure that Machida uses the correct version of Python if you have multiple versions installed on your computer.

## Installing Virtualenv

Follow the instructions on [the virtualenv website](https://virtualenv.pypa.io/en/stable/installation/).

## Setting up Virtualenv for your Application

To create a virtualenv for your application, run the following command


{% codetabs name="Python 2.7", type="py" -%}
virtualenv --python=python2 ENV
{% language name="Python 3", type="py" -%}
virtualenv --python=python3 ENV
{%- endcodetabs %}

This will create a directory named `ENV` and set up all of the scripts and dependencies required to run an isolated Python 2 virtual environment, located in `ENV`.

### Import Errors when Loading your Application

If you have more than one Python version installed, virtualenv may set up the import paths incorrectly, or an alias may result in the wrong Python version being run. In that case, you may encounter errors such as

```python
Traceback (most recent call last):
  File "wallaroo-{{ book.wallaroo_version }}/examples/python/alerts_stateful/alerts.py", line 18, in <module>
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
Could not load module 'alerts'
```

In order to work correctly, virtualenv needs to be set up with the correct Python path. To do this, use `which` to get the absolute path of your intended Python version:

```bash
virtualenv --python=`which python` ENV
```

If you use a different Python, such as `python2` or `python3.5`, then substitute that into the `which` command:

```bash
virtualenv --python=`which python3.5` ENV
```

**Note**: it is critical that the Python version in the virtualenv is compatible with the version of Machida. For example, if you're using machida3, you need to setup your virtualenv for Python 3, and if you are using machida, you need to set up the virtualenv for Python 2.

## Cleaning up a Virtualenv

To clean up or remove an installed virtualenv, all you need to do is delete the directory you created.

For the `ENV` virtualenv set up above, the following will remove it entirely:

```bash
rm -fr ENV
```

## Using Virtualenv

It is assumed that every shell you start for Wallaroo was set up by following [Starting a new shell for Wallaroo](/book/getting-started/starting-a-new-shell.md) for your environment.

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

{% codetabs name="Python 2.7", type="py" -%}
source ENV/bin/activate
export PYTHONPATH="$HOME/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/machida/lib:$HOME/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/examples/python/alerts_stateful"
machida --application-module alerts \
  --out 127.0.0.1:5555 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:6000 --data 127.0.0.1:6001 --name worker-name \
  --external 127.0.0.1:5050 --cluster-initializer --ponythreads=1 \
  --ponynoblock
{% language name="Python 3", type="py" -%}
source ENV/bin/activate
export PYTHONPATH="$HOME/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/machida/lib:$HOME/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/examples/python/alerts_stateful"
machida3 --application-module alerts \
  --out 127.0.0.1:5555 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:6000 --data 127.0.0.1:6001 --name worker-name \
  --external 127.0.0.1:5050 --cluster-initializer --ponythreads=1 \
  --ponynoblock
{%- endcodetabs %}

Please be aware that you'll still need to setup a sink as well. To run a sink for our example with Data Receiver, run

```bash
data_receiver --framed --listen 127.0.0.1:5555 --ponythreads=1 --ponynoblock
```

or if you prefer to log the output into a file:

```bash
data_receiver \
--framed --listen 127.0.0.1:5555 --ponythreads=1 --ponynoblock > output
```

The contents of your pipeline's decoder will be added to a file named output in the directory from which this is run.
