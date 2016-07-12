

class StreamConnection {
    constructor(id, dispatcher, channelHub, defaultRate) {
        this.id = id;
        this.dispatcher = dispatcher;
        this.source = null;
        this.transformer = x => x;
        this.channelHub = channelHub;
        this.channel = this.channelHub.channel("stream-connection-" + this.id);
        this.msgType = "stream-msg-" + this.id;
        this.interval = defaultRate || 1000;
        this.isInitialized = false;
    }
    connect(source) {
        if (this.source) throw new Error("You cannot connect more than one source stream on a single connection!");

        this.source = source;
        return this;
    }
    withTransformer(transformer) {
        if (this.isInitialized) throw new Error("This connection cannot be configured twice!");

        this.transformer = transformer;
        return this;
    }
    atRate(ms) {
        if (this.isInitialized) throw new Error("This connection cannot be configured twice!");

        this.interval = ms;
        return this;
    }
    start() {
        if (!this.source) throw new Error("A source stream is required!");

        const spout = new Spout(this.channel, this.source).withConstantInterval(this.interval).connectTo(this.msgType);
        spout.start();

        this.channel.on(this.msgType, function(data) {
            this.dispatcher.dispatch(this.transformer(data));
        }.bind(this));

        this.isInitialized = true;
        return this;
    }
}


export default class StreamPusher {
    constructor() {

    }
}