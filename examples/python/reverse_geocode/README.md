# Reverse Geocode

This is an example application that receives coordinate pairs as input and outputs the
nearest matching geographical region from a geocodes database.

This example is intended to exercise [virtualenv](https://virtualenv.pypa.io/en/stable/).

You will need a working [Wallaroo Python API](/book/python/intro.md).

## Setting up virtualenv

First, install virtualenv according to its [installation instructions](https://virtualenv.pypa.io/en/stable/installation/).

Now, create a virtual environment, and install `reverse_geocoder` from pip.

```bash
virtualenv ENV
source ENV/bin/activate
pip install reverse_geocoder
```

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
