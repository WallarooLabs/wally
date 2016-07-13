import java.util.*;
import java.io.*;
import java.nio.*;
import java.util.concurrent.atomic.*;

class wordlength {
    public static final String SEPARATOR = ",";

    private static final AtomicInteger receivedCount = new AtomicInteger(0);
    private static final AtomicInteger processedCount = new AtomicInteger(0);

    public static void main(String[] args) throws Exception {
        Buffy.getInstance().log("Word-Length-Count: Process Started");

        while (true) {
            byte[] msgAsBytes = Buffy.getInstance().in().next();
            if (msgAsBytes == null) {
                Buffy.getInstance().log("Stdin has been forcibly closed w/out sending poison pill. Assume process is done. Exiting");
                shutdown();
            }

            ExternalMessage<String> msg = decode(msgAsBytes);

            if (msg != null && msg.data != null) {
                String data = msg.data.trim();
                if (data.length() > 0) {
                    if (data.equals("POISON")) {
                        Buffy.getInstance().log("Received poison pill. Exiting.");
                        shutdown();
                    } else {
                        Buffy.getInstance().log("Received: " + data);
                        receivedCount.incrementAndGet();
                        String result = process(data);
                        ExternalMessage<String> resultMsg = msg.withResult(result); 
                        byte[] resultAsBytes = encode(resultMsg);
                        Buffy.getInstance().out().send(resultAsBytes);
                        processedCount.incrementAndGet();
                    }
                }
            }
        }
    }

    private static void shutdown() {
        Buffy.getInstance().out().close();
        Buffy.getInstance().in().close();
        Buffy.getInstance().log("Word-Length-Count: Process Shutting down...");
        Buffy.getInstance().log("Word-Length-Count: Received " + receivedCount.get() + ", Processed " + processedCount.get());
        Buffy.getInstance().log("Word-Length-Count: Done");
        System.exit(0);
    }

    private static String process(String line) {
        String result = line + ":" + Integer.toString(line.length());
        return result;
    }

    private static ExternalMessage<String> decode(byte[] msgAsBytes) {
        String msgAsString = new String(msgAsBytes);
        try {
            Buffy.getInstance().log("Decoding: " + msgAsString);
            String[] msgParts = msgAsString.split(SEPARATOR);
            return new ExternalMessage<String>(msgParts[0],
                msgParts[1],
                msgParts[2],
                msgParts[3],
                msgParts[4]);
        } catch (Exception ex) {
            Buffy.getInstance().log("Error decoding: " + msgAsString, ex);
            return null;
        }
    }

    private static byte[] encode(ExternalMessage<String> m) {
        String msgAsString = m.id + SEPARATOR + 
            m.source_ts + SEPARATOR +
            m.last_ingress_ts + SEPARATOR + 
            m.sent_to_external_ts + SEPARATOR + 
            m.data;
        return msgAsString.getBytes();
    }

    public static class ExternalMessage<T> {
        // storing these as Strings instead of Longs as Pony U64's don't fit into java signed Long's.
        public final String id;
        public final String source_ts;
        public final String last_ingress_ts;
        public final String sent_to_external_ts;
        public final T data;

        public ExternalMessage(String id, String s_ts, String l_i_ts, String s_t_e_ts, T data) {
            this.id = id;
            this.source_ts = s_ts;
            this.last_ingress_ts = l_i_ts;
            this.sent_to_external_ts = s_t_e_ts;
            this.data = data;
        }

        public <S> ExternalMessage<S> withResult(S result) {
            return new ExternalMessage<S>(id, source_ts, last_ingress_ts, sent_to_external_ts, result);
        }
    }

    // **************************************************************************************
    // **************************************************************************************
    // **************************************************************************************
    // The beginnings of what would evolve into the Java API of Buffy for external processes
    //
    // Everything below here should be part of a Buffy Java Library we provide(?) that 
    // supports some subset of the features in Buffy for Pony based Steps in Java as well.
    // 
    // They are all in one file because I haven't gotten External Process API working with
    // jars/uberjars/etc.
    // **************************************************************************************
    // **************************************************************************************
    // **************************************************************************************

    public static final class Buffy {
        private static volatile Buffy buffy;

        public static Buffy getInstance() {
            if (buffy == null) {
                synchronized (Buffy.class) {
                    if (buffy == null) {
                        buffy = new Buffy();
                    }
                }
            }
            return buffy;
        }

        private final BuffyMessageReader reader;
        private final BuffyMessageWriter writer;

        public Buffy() {
            reader = new BuffyMessageReader(System.in);
            writer = new BuffyMessageWriter(System.out);
        }

        public BuffyMessageReader in() {
            return reader;
        }

        public BuffyMessageWriter out() {
            return writer;
        }

        public void log(String msg) {
            System.err.println("##### External Process: Java: " + msg);
        }

        public void log(String msg, Exception e) {
            System.err.println("##### External Process: Java: " + msg);
            e.printStackTrace(System.err);
        }
    }

    public static final class BuffyMessageReader {
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

    public static final class BuffyMessageWriter {
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
}