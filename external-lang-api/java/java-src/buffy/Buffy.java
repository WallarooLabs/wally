package buffy;

import java.util.concurrent.atomic.*;

public final class Buffy<In, Out> {
    public static class Builder<In, Out> {
	    private Computation<In, Out> computation = null;
    	private Codec<In, Out> codec = null;
    	private String name = null;

    	public Builder computation(Computation<In, Out> computation) {
    		this.computation = computation;
    		return this;
    	}

    	public Builder codec(Codec<In, Out> codec) {
    		this.codec = codec;
    		return this;
    	}

    	public Builder name(String name) {
    		this.name = name;
    		return this;
    	}

    	public Buffy build() {
    		if (computation == null) throw new NullPointerException("computation");
    		if (codec == null) throw new NullPointerException("codec");
    		if (name == null) throw new NullPointerException("name");
    		return new Buffy<In, Out>(computation, codec, name);
    	}
    }

    private final Computation<In, Out> computation;
    private final Codec<In, Out> codec;
    private final String logPrefix;
    private final AtomicInteger receivedCount = new AtomicInteger(0);
    private final AtomicInteger processedCount = new AtomicInteger(0);
    private final BuffyMessageReader in = new BuffyMessageReader(System.in);
    private final BuffyMessageWriter out = new BuffyMessageWriter(System.out);

    private Buffy(Computation<In, Out> computation, Codec<In, Out> codec, String name) {
    	this.computation = computation;
    	this.codec = codec;
    	this.logPrefix = "##### External Process: Java: " + name + ": ";
    }

    public void run() {
        log("Process Started");

        while (true) {
            byte[] msgAsBytes = in.next();
            if (msgAsBytes == null) {
                log("Input has been forcibly closed w/out sending poison pill. Assume process is done. Exiting");
                shutdown();
                return;
            }

            if (codec.isShutdownSignal(msgAsBytes, this)) {
                log("Received poison pill. Exiting.");
                shutdown();
                return;
            } else {
                receivedCount.incrementAndGet();
            	byte[] resultAsBytes = process(msgAsBytes);
                try {
	            	if (resultAsBytes != null) {
		                out.send(resultAsBytes);
		                processedCount.incrementAndGet();
	            	}
                } catch (Exception e) {
                	log("Error sending processed message.", e);
                }
            }
        }
    }

    private byte[] process(byte[] msgAsBytes) {
        try {
        	ExternalMessage<In> msg = codec.decode(msgAsBytes, this);
            log("Received: " + msg.toString());
            Out result = computation.execute(msg.data, this);
            ExternalMessage<Out> resultMsg = msg.withResult(result); 
            return codec.encode(resultMsg, this);
        } catch (Exception e) {
        	log("Error processing message.", e);
        	return null;
        }
    }

    private void shutdown() {
        out.close();
        in.close();
        log("Process Shutting down...");
        log("Received " + receivedCount.get() + ", Processed " + processedCount.get());
        log("Done");
    }

    public void log(String msg) {
        System.err.println(logPrefix + msg);
    }

    public void log(String msg, Exception e) {
        System.err.println(logPrefix + msg);
        e.printStackTrace(System.err);
    }

}