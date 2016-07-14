package buffy;

import java.util.*;
import java.io.*;

final class BuffyMessageReader {
    private static final int headerSizeInBytes = 4;

    private final DataInputStream in;

    public BuffyMessageReader(InputStream in) {
        this.in = new DataInputStream(new BufferedInputStream(in));
    }

    public byte[] next() {
        try {
            int messageSize = readNextMessageSize();
            if (messageSize == -1) return null;
            byte[] buffer = new byte[messageSize];
            in.readFully(buffer);
            return buffer;
        } catch (EOFException eof) {
            throw new RuntimeException("End of stream reached, could not read next message.");
        } catch (IOException io) {
            throw new RuntimeException("Stream has been closed, could not read next message.");
        }
    }

    public void close() {
        try {
            in.close();
        } catch (IOException io) {
            throw new RuntimeException(io);
        }
    }

    private int readNextMessageSize() {
        try {
            return in.readInt();
        } catch (EOFException eof) {
            throw new RuntimeException("End of stream reached, could not read next message header");
        } catch (IOException io) {
            //TODO:
            //we're going to swallow this as this is only way we have of knowing that this process is being shutdown till 
            //some new features are being added to buffy to instead send us a poison pill
            //throw new RuntimeException("Stream has been closed, could not read next message header");
            return -1;
        }
    }
}