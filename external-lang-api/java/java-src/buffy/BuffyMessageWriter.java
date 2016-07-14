package buffy;

import java.util.*;
import java.io.*;
import java.nio.*;

final class BuffyMessageWriter {
    private final BufferedOutputStream out;

    public BuffyMessageWriter(OutputStream out) {
        this.out = new BufferedOutputStream(out);
    }

    public void send(byte[] msgAsBytes) {
        try {
            Integer length = msgAsBytes.length;
            byte[] header = ByteBuffer.allocate(4).putInt(length).array();
            out.write(header);
            byte[] payload = ByteBuffer.allocate(length).put(msgAsBytes).array();
            out.write(payload);
            out.flush();
        } catch (IOException io) {
            throw new RuntimeException(io);
        }
    }

    public void close() {
        try {
            out.close();
        } catch (IOException io) {
            throw new RuntimeException(io);
        }
    }
}    