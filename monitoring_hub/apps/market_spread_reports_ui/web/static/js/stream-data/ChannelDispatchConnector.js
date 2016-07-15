class ChannelConnection {
    constructor(channel, dispatcher) {
        this.dispatcher = dispatcher;
        this.channel = channel;
        this.dispatchingFor = {};
    }
    dispatchOn(msgType, transformer) {
        if (!this.dispatchingFor[msgType]) {
            this.dispatchingFor[msgType] = [];
        }
        this.confirmOrAddDispatch(msgType, transformer);
        return this;
    }
    confirmOrAddDispatch(msgType, transformer) {
        if (!this.dispatchingFor[msgType].includes(transformer)) {
            this.channel.on(msgType, function(data) {
                this.dispatcher.dispatch(transformer(data));
            }.bind(this));
            this.dispatchingFor[msgType].push(transformer);
        }
    }

}

export default class ChannelDispatchConnector {
    constructor(channelHub, dispatcher) {
        if (!dispatcher || !dispatcher.dispatch) throw new Error("ChannelDispatchConnector requires a dispatcher with a dispatch method!");
        this.dispatcher = dispatcher;
        this.channelHub = channelHub;
        this.channelHub.connect();
        this.channelConnections = {};
    }
    connectTo(chName) {
        if (this.channelConnections[chName]) {
            return this.channelConnections[chName];
        } else {
            const channel = this.channelHub.channel(chName);
            const channelConnection = new ChannelConnection(channel, this.dispatcher);
            this.channelConnections[chName] = channelConnection;
            return channelConnection;
        }
    }
}