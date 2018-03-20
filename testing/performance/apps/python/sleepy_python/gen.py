# Copyright 2018 Wallaroo Labs Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#  implied. See the License for the specific language governing
#  permissions and limitations under the License.

from random import randint
from struct import pack


def write_nonce(nonce):
    partition_selector = randint(0,60000)
    # We're writing 1024 bytes with a size header
    nonce.write(pack(">II", 1024, partition_selector))
    for _ in range(1020 / 4):
        nonce.write(pack("I", randint(0,2**32)))

with open("_nonces.bin", "wb") as nonces:
    for _ in range(1024): # Roughly 1M of data + 32bit frame overhead
        write_nonce(nonces)
