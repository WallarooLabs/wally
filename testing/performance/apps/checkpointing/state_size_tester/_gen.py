# Create files for 100, 1k, 10k, 100k keys
# using the Size:U32, Key: U32, Val:U32 format

from struct import pack

for num_keys in [100, 1000, 10000, 100000]:
    filename='checkpoint_perf_test_{}_keys.msg'.format(num_keys)
    with open(filename, 'wb') as f:
        for x in range(num_keys):
            f.write(pack('>III', 8, x, 1))
    print("Wrote {}".format(filename))
