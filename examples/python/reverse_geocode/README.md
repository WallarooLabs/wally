# Reverse Geocode

This is an example application that receives coordinate pairs as input and outputs the
nearest matching geographical region from a geocodes database.

This example is intended to exercise [virtualenv](https://virtualenv.pypa.io/en/stable/).

You will need a working [Wallaroo Python API](/book/python/intro.md).

## Setting up virtualenv

First, install virtualenv according to its [installation instructions](https://virtualenv.pypa.io/en/stable/installation/).

Now, create a virtual environment, and install `reverse_geocoder` from pip.
OS X users should not omit the `--python` argument to `virtualenv` in order to work around a known problem with Python 2.7.

```bash
rm -rf ENV
virtualenv ENV --python=`which python`
# NOTE: If you are a CSH or FISH shell user, adjust the "source" command below
source ENV/bin/activate
pip install reverse_geocoder
```

#### A note on Python versions
Some platforms use a pip command that is versioned, for example, `pip2` and/or `pip2.7` for use with Python 2.7 or `pip3` for use with Python 3.x. If that is the case for your platform, please make sure you install virtualenv for Python 2, as this is the version that will be used by `machida`.

## Running Reverse

In a shell, start up the Metrics UI if you don't already have it running:

```bash
docker start mui
```

In a shell, set up a listener:

```bash
nc -l 127.0.0.1 7002
```

In another shell, export the current directory and `wallaroo.py` directories to `PYTHONPATH`:

In another shell, set up your environment variables if you haven't already done so. Assuming you installed Machida according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
```

Run `machida` with `--application-module reverse_geocode`:

```bash
machida --application-module reverse_geocode --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name \
  --ponythreads=1
```

In a third shell, send some messages:

```bash
../../../giles/sender/sender --host 127.0.0.1:7010 --file coords.msg \
--batch-size 1 --interval 250_000_000 --messages 3 \
--ponythreads=1 --binary --variable-size
```
