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


# File path for our output (it will overwrite anything that's already there)
nonce_file = "_nonces.bin"

# Size in bytes, including the partition key but excluding the frame header
nonce_size = 1024

# Number of nonces to generate
nonce_count = 1024


def write_nonce(file):
    partition_selector = randint(0,60000)
    file.write(pack(">II", nonce_size, partition_selector))
    pad = randint(0, 2**32)
    for _ in range((nonce_size - 4) / 4):
        file.write(pack(">I", pad))



with open(nonce_file, "wb") as nonces:
    for _ in range(nonce_count):
        write_nonce(nonces)
