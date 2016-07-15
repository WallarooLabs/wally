import PusherClient from "pusher-js";

class PusherChannel {
    constructor(chName, pusherCh) {
        this.chName = chName;
        this.pusherCh = pusherCh;
    }
    on(msgType, cb) {
        this.pusherCh.bind(msgType, cb);
    }
}

export default class PusherChannels {
    constructor(config) {
        this.pusherClient = null;
        this.appKey = config.appKey;

        this.channels = {};
    }
    connect() {
        this.pusherClient = new PusherClient(this.appKey);
    }
    channel(chName) {
        if (this.channels[chName]) {
            return this.channels[chName];
        } else {
            const newChannel = new PusherChannel(chName, this.pusherClient.subscribe(chName));
            this.channels[chName] = newChannel;
            return newChannel;
        }
    }
    on(chName, msgType, cb) {
        if (this.channels[chName]) {
            this.channels[chName].on(msgType, cb);
        } else {
            const newChannel = new PusherChannel(chName, this.pusherClient.subscribe(chName));
            this.channels[chName] = newChannel;
            newChannel.on(msgType, cb);
        }
    }
}