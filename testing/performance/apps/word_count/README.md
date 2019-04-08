# Word Count

## Running

In a separate shell, each:

1. Start a listener

```bash
../../../../utils/data_receiver/data_receiver --framed --ponythreads=1 --ponynoblock \
--ponypinasio --ponypin -l 127.0.0.1:5555 > received.txt
```

2. Start the application

```bash
./word_count -i 127.0.0.1:7000 -o 127.0.0.1:5555 -m 127.0.0.1:5001 -c \
127.0.0.1:6000 -d 127.0.0.1:6001 -n node-name -t --ponythreads=4
```

3. Start a sender

```bash
../../../../giles/sender/sender -h 127.0.0.1:7000 -m 5000000 -s 300 \
-i 5_000_000 -f testing/data/word_count/bill_of_rights.txt --ponythreads=1
```
