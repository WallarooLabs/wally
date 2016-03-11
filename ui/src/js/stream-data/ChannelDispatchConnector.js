class ChannelConnection {
    constructor(channel, dispatcher) {
        this.dispatcher = dispatcher;
        this.channel = channel;
    }
    dispatchOn(msgType, transformer) {
        this.channel.on(msgType, function(data) {
            this.dispatcher.dispatch(transformer(data));
        }.bind(this));
    }
}

export default class ChannelDispatchConnector {
    constructor(channelHub, dispatcher) {
        if (!dispatcher || !dispatcher.dispatch) throw new Error("ChannelDispatchConnector requires a dispatcher with a dispatch method!");
        this.dispatcher = dispatcher;
        this.channelHub = channelHub;
        this.channelHub.connect();
    }
    connectTo(chName) {
        const channel = this.channelHub.channel(chName);
        return new ChannelConnection(channel, this.dispatcher);
    }
}