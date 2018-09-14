import select
import psycopg2
import psycopg2.extensions
import sys
import json
from text_documents import TextStream, parse_text_stream_addr

conn = psycopg2.connect("dbname=wallaroo user=postgres password=postgres host=localhost")
conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)
text_stream_addr = parse_text_stream_addr(sys.argv)
extension = TextStream(*text_stream_addr).extension()

curs = conn.cursor()
# curs.execute("""
# CREATE TABLE BILL_OF_RIGHTS
# (
#     bill_of_rights_id int PRIMARY KEY,
#     content TEXT
# );""")

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

# curs.execute("""
#     CREATE TRIGGER BILL_OF_RIGHTS_AFTER
#     AFTER INSERT
#     ON BILL_OF_RIGHTS
#     FOR EACH ROW
#     EXECUTE PROCEDURE NOTIFY();
# """)

curs.execute("LISTEN wallaroo_example;")
print "Waiting for notifications on channel 'wallaroo_example'"
while True:
    if select.select([conn],[],[],5) == ([],[],[]):
        print "Timeout"
    else:
        conn.poll()
        while conn.notifies:
            notify = conn.notifies.pop(0)
            # print "Got NOTIFY:", notify.pid, notify.channel, notify.payload
            payload = json.loads(notify.payload)
            extension.write(payload["content"])
