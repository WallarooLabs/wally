import json
import select
import signal
import sys

import psycopg2
import psycopg2.extensions
from text_documents import TextStream, parse_text_stream_addr

conn = psycopg2.connect(
    "dbname=wallaroo user=postgres password=postgres host=localhost")
conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)
text_stream_addr = parse_text_stream_addr(sys.argv)
extension = TextStream(*text_stream_addr).extension()

curs = conn.cursor()
curs.execute("""
CREATE TABLE BILL_OF_RIGHTS
(
    bill_of_rights_id SERIAL PRIMARY KEY,
    content TEXT
);""")

curs.execute("""
    CREATE OR REPLACE FUNCTION NOTIFY() RETURNS trigger AS
    $BODY$
    BEGIN
        PERFORM pg_notify('wallaroo_example', row_to_json(NEW)::text);
        RETURN new;
    END;
    $BODY$
    LANGUAGE 'plpgsql' VOLATILE COST 100;
""")

curs.execute("""
    CREATE TRIGGER BILL_OF_RIGHTS_AFTER
    AFTER INSERT
    ON BILL_OF_RIGHTS
    FOR EACH ROW
    EXECUTE PROCEDURE NOTIFY();
""")


def signal_handler(sig, frame):
    print 'Removing Table BILL_OF_RIGHTS....'
    curs.execute("DROP TABLE BILL_OF_RIGHTS")
    curs.close()
    conn.close()
    sys.exit(0)


signal.signal(signal.SIGINT, signal_handler)

curs.execute("LISTEN wallaroo_example;")
print "Waiting for notifications on channel 'wallaroo_example'"
while True:
    if select.select([conn], [], [], 5) == ([], [], []):
        print "Timeout"
    else:
        conn.poll()
        while conn.notifies:
            notify = conn.notifies.pop(0)
            payload = json.loads(notify.payload)
            extension.write(payload["content"])
