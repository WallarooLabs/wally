#!/usr/bin/env python3.5

def fields_list_for(line):
    return line.strip("\n").split(", ")

def timestamp_for(line):
    return fields_list_for(line)[0]

def payload_for(line):
    return fields_list_for(line)[1]

def fields_for(line):
    lst = fields_list_for(line)
    return {
        "timestamp": lst[0],
        "payload": lst[1]
    }

def records_for(file):
    records = []
    for line in file.readlines():
        fields = fields_for(line)
        if len(fields) == 0: continue
        records.append(fields_for(line))
    return records
