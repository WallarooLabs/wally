# Decoding `giles/receiver` Output

Since Giles-Receiver is designed to be a fast sink receiver, it doesn't decode the data it receives from Wallaroo, but instead saves as frame encoded binary data.
As the obvious next step is for a user to want to consume this data, we also provide [Fallor](https://github.com/WallarooLabs/wallaroo/tree/release-0.1.1/testing/tools/fallor) to decode this data.

## Fallor Command-Line Options

Fallor takes the following arguments:

```bash
PARAMETERS:
-------------------------------------------------------------------------------
--input/-i [Sets file to read from (default: received.txt)]
--output/-o [Sets file to write to (default: fallor-readable.txt)]
-------------------------------------------------------------------------------
```

## Decoded Structure

Giles receiver stores data as frame-encoded tuples of (_received timestamp_, _binary blob_). As `fallor` decodes the file, it saves each decoded tuple in a new line, with the _received timestamp_, followed by a comma, a space, and the data received by giles-receiver--unchanged.
If the data received by giles-receiver was text, then it will show as text. However, if it the data is anything other than text, then that data will show as a binary blob, which may or may not be readable as text.

The next section describes how to create your own encoder if your application's output data is not text.

## Binary Data

If your application is sending binary encoded data from its sink, then even after decoding the receiver's output file, that data will still remain a binary data.

In order to decode that data, you will need to build your own decoder.

There are two ways to go about this:

1. Use `fallor` to decode the receiver's output file, and then consume the file as text, splitting on the first comma, and treating the remainder of the line as binary data. This method only works if your binary data is guaranteed to not contain any new lines, however.
2. Write a custom decoder to for the `giles-receiver` output file your application generated.

### Writing a Custom Output File Decoder

If you need to write a custom file decoder for the giles-receiver output file, then may want to refer to the [Giles-receiver output encoding](/book/wallaroo-tools/giles-receiver.md#output-file-encoding) section.

### Template Custom Output File Decoder in Python

A Python template for a custom output file decoder is provided below. It requires `click` to be installed (`sudo pip install click`), but if you don't need a CLI, you can forego this requirement.

In this example, [struct.unpack](https://docs.python.org/2/library/struct.html#struct.unpack) is used in conjunction with a user-defined unpacking specification.
In addition, the user may also determine if the `msg_length` included by `giles/receiver` should be used when unpacking the application's binary blob.

For example, if the binary data is a variable length string, then `--format '>{}s' --size-dependent` will tell the decoder to decode is a string.
If, instead, the binary data is a list of 32-bit signed integers, then the user will need to override (in the code) the `fmt_function` provided.
A replacement function could be

```python
def format_function(size):
    # Divide size by 4 to get number of integers in the list
    return '>{}I'.format(size/4)

# run decode_file with the new format_function
decode_file(format_function, f_in, f_out)
```

The complete template is:

```python

# decoder.py

import click
import struct
import sys


def decode_msg(fmt, msg_data):
    return struct.unpack(fmt, msg_data)


LENGTH_WITH_TIMESTAMP_FMT = '>LQ'
LENGTH_WITH_TIMESTAMP_LENGTH = 12
def decode_file(fmt_function, f_in, f_out):
    # get file length
    f_in.seek(0,2)
    total_size = f_in.tell()
    f_in.seek(0,0)

    # start reading
    while total_size > 0:
        msg_len, ts = struct.unpack(LENGTH_WITH_TIMESTAMP_FMT, f_in.read(12))
        total_size -= (12 + msg_len)
        msg = struct.unpack(fmt_function(msg_len), f_in.read(msg_len))[0]
        f_out.write(", ".join((str(ts), msg)))
        f_out.write("\n")


@click.command()
@click.option('--input', '-i', 'input_path', nargs=1, required=True, type=str,
              help='Path of file to open for decoding')
@click.option('--output', '-o', 'output_path', nargs=1, required=True, type=str,
              help='Path of file to open for writing output')
@click.option('--format', '-f', 'fmt', nargs=1, required=True, type=str,
              help='format string to provide struct.unpack')
@click.option('--size-dependent', '-s', 'size_dependent', is_flag=True, default=False,
              help='Recompute format for message size')
def decode_cli(input_path, output_path, fmt, size_dependent):
    with open(output_path, 'wb') as f_out:
        with open(input_path, 'rb') as f_in:
            if size_dependent:
                # If you have multiple size-dependent arguments, replace this
                # function with your own custom one!
                fmt_function = lambda s: fmt.format(s)
            else:
                fmt_function = lambda s: fmt
            decode_file(fmt_function, f_in, f_out)


if __name__ == '__main__':
    decode_cli()
```
