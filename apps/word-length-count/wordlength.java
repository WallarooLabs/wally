import buffy.*;

class wordlength {
    public static void main(String[] args) throws Exception {
        new Buffy.Builder()
            .computation(new WordLengthComputation())
            .codec(new CsvCodec())
            .name("Word Length Count")
            .build()
            .run();
    }

    public static class WordLengthComputation implements Computation<String, String> {
        public String execute(String in, Buffy buffy) {
            return in + ":" + Integer.toString(in.length());
        }
    }

    public static class CsvCodec implements Codec<String, String> {
        private static final String SEPARATOR = ",";

        public ExternalMessage<String> decode(byte[] msgAsBytes, Buffy buffy) {
            String msgAsString = new String(msgAsBytes);
            try {
                buffy.log("Decoding: " + msgAsString);
                String[] msgParts = msgAsString.split(SEPARATOR);
                return new ExternalMessage<String>(msgParts[0],
                    msgParts[1],
                    msgParts[2],
                    msgParts[3],
                    msgParts[4]);
            } catch (Exception ex) {
                buffy.log("Error decoding: " + msgAsString, ex);
                return null;
            }
        }

        public byte[] encode(ExternalMessage<String> m, Buffy buffy) {
            String msgAsString = m.id + SEPARATOR + 
                m.source_ts + SEPARATOR +
                m.last_ingress_ts + SEPARATOR + 
                m.sent_to_external_ts + SEPARATOR + 
                m.data;
            return msgAsString.getBytes();
        }

        public boolean isShutdownSignal(byte[] signal, Buffy buffy) {
            //TODO: shutdown signals not working on pony-buffy side yet
            return false;
        }
    }  
}