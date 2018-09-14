from __future__ import print_function
import os
import time
import sys
import psycopg2
import psycopg2.extensions

conn = psycopg2.connect("dbname=wallaroo user=postgres password=postgres host=localhost")
conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)

curs = conn.cursor()

project = os.path.dirname(__file__)
bill_path = os.path.join(project, "data/bill_of_rights.txt")
with open(bill_path, 'r') as file:
    bill = file.read()

# curs.execute("""
# CREATE TABLE BILL_OF_RIGHTS
# (
#     bill_of_rights_id SERIAL PRIMARY KEY,
#     content TEXT
# );""")

sql = """INSERT INTO bill_of_rights(content) VALUES(%s);"""
while True:
    curs.execute(sql, (bill,))
    conn.commit()
