
export default class PhoenixChannels {
    constructor(config) {
        this.socket = config.socket;

        this.channels = {};
    }
    connect() {
        this.socket.connect();
    }
    channel(chName) {
        if (this.channels[chName]) {
            return this.channels[chName];
        } else {
            const newChannel = this.socket.channel(chName);
            newChannel.join();
            this.channels[chName] = newChannel;
            return newChannel;
        }
    }
    on(chName, msgType, cb) {
        if (this.channels[chName]) {
            this.channels[chName].on(msgType, cb);
        } else {
            const newChannel = this.socket.channel(chName);
            this.channels[chName] = newChannel;
            newChannel.join();
            newChannel.on(msgType, cb);
        }
    }
}