package buffy;

public interface Codec<In, Out> {
    ExternalMessage<In> decode(byte[] msgAsBytes, Buffy buffy);

    byte[] encode(ExternalMessage<Out> msg, Buffy buffy);

    boolean isShutdownSignal(byte[] signal, Buffy buffy);
}