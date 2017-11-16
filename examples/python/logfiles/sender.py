import sys
import socket
import struct


def send_message(conn, msg):
    conn.sendall(struct.pack('>I', len(msg)))
    conn.sendall(msg)

if __name__ == '__main__':
    wallaroo_host = sys.argv[1]
    file_to_send = sys.argv[2]
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    add = sys.argv[1].split(':')
    wallaroo_input_address = (add[0], int(add[1]))
    print 'connecting to Wallaroo on %s:%s' % wallaroo_input_address
    sock.connect(wallaroo_input_address)
    with open(file_to_send) as f:
        for line in f:
            send_message(sock, line)
    send_message(sock, "END_OF_DAY") 
