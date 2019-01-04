import struct

num_bytes = 4 + 1 + 8
correct_count = 1
with open('alphabet.out', 'rb') as f:
    while True:
        try:
            (len, letter, count) = struct.unpack('>IsQ', f.read(num_bytes))
            ## print "len %d letter %s count %d" % (len, letter, count)
            if len != 9:
                print "OUCH, len = %d" % len
            if letter != 'n':
                print "OUCH, letter = %d" % letter
            if count != correct_count:
                print "OUCH, count %d != correct_count %d" % (count, correct_count)
            correct_count = correct_count + 1
        except:
            print "exception or EOF, correct_count = %d" % correct_count
            break
