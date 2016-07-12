import UIDGen from "../util/UIDGen.js";
import Channels from "./channels/Channels.js";
import PusherChannels from "./channels/PusherChannels.js";
import ActionCreators from "../buffy-ui/actions/ActionCreators.js";
import Spout from "./spouts/Spout.js";


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
    onChannel(channel) {
        this.channel = this.channelHub.channel(channel);
        return this;
    }
    forMsgType(msgType) {
        this.msgType = msgType;
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

const idGen = new UIDGen();

export default class StreamDispatchConnector {
    constructor(dispatcher, channelHub) {
        if (!dispatcher || !dispatcher.dispatch) throw new Error("StreamDispatchConnector requires a dispatcher with a dispatch method!");
        this.dispatcher = dispatcher;
        this.defaultRate = 1000;
        this.channelHub = channelHub || new Channels();
        this.channelHub.connect();
    }
    connect(source) {
        const connection = new StreamConnection(idGen.next(), this.dispatcher, this.channelHub, this.defaultRate);
        return connection.connect(source);
    }
}
