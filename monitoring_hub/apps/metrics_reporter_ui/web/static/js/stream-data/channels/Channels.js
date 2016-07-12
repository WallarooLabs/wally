class Channel {
    constructor(name) {
        this.name = name;
        this.msgTypes = {};
    }
    push(msgType, msg) {
        if (this.msgTypes[msgType]) {
            this.msgTypes[msgType].forEach(cb => cb(msg));
        }
    }
    on(msgType, cb) {
        if (this.msgTypes[msgType]) {
            this.msgTypes[msgType].push(cb);
        } else {
            this.msgTypes[msgType] = [cb];
        }
    }
}

export default class Channels {
    constructor() {
        this.channels = {};
    }
    connect() {
        // no-op
    }
    channel(chName) {
        if (this.channels[chName]) {
            return this.channels[chName];
        } else {
            const newChannel = new Channel(chName);
            this.channels[chName] = newChannel;
            return newChannel;
        }
    }
    push(chName, msgType, msg) {
        const channel = this.channel(chName);
        channel.push(msgType, msg);
    }
    on(chName, msgType, cb) {
        const channel = this.channel(chName);
        channel.on(msgType, cb);
    }
}