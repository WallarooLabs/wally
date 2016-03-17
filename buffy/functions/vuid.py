#!/usr/bin/env python3

"""vuid provides a get_vuid() method which returns a 6-digit long
string id"""


import base64
import random


def get_vuid():
    return (base64.urlsafe_b64encode(str(random.randint(100000,999999))
            .encode()).decode())
