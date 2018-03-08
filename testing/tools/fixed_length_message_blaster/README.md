# Fixed Length Message Blaster

Reads fixed length messages from a file and blasts them as fast as possible at a TCP location. Loads all data from a file into memory and potentially creates many copies of it in order to:

* keep data distribution of messages even with the file
* match the required batch size supplied by the user

Be wary with using with particularly large data files.

## Usage

Has 4 required parameters:

* --host ip address to send to, in the format of "HOST:PORT" for example 127.0.01:7669
* --file the file to read data from
* --msg-size the size of each message in the file
* --batch-size the number of messages to send each time we send

```bash
./fixed_length_message_blaster \
--file ../../data/market_spread/nbbo/350-symbols_initial-nbbo-fixish.msg \
--host 127.0.0.1:7669 --batch-size 100 --msg-size 46
```
