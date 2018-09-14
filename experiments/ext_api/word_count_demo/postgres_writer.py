import json
import select
import signal
import sys

import psycopg2
import psycopg2.extensions
from word_counts import CountStream, parse_count_stream_addr

count_stream_addr = parse_count_stream_addr(sys.argv)
extension = CountStream(*count_stream_addr).extension()
conn = psycopg2.connect(
    "dbname=wallaroo user=postgres password=postgres host=localhost")
conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)

curs = conn.cursor()
curs.execute("""
CREATE TABLE COUNT
(
    count_id SERIAL PRIMARY KEY,
    word TEXT,
    count INT
);""")


def signal_handler(sig, frame):
    print 'Removing Table COUNT....'
    curs.execute("DROP TABLE COUNT")
    curs.close()
    conn.close()
    sys.exit(0)


signal.signal(signal.SIGINT, signal_handler)

while True:
    word, count = extension.read()
    curs.execute("""
        INSERT INTO COUNT (word, count)
        VALUES (%s, %s);
    """, (word, count))
