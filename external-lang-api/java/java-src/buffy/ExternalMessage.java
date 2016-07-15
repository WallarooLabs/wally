package buffy;

public class ExternalMessage<T> {
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