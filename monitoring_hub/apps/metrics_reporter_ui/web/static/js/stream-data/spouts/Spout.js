export default class Spout {
    constructor(channel, source, intervalFn) {
        if (!(source.next && typeof(source.next) === "function")) throw new Error("Spouts require a source with a next method!");

        this.channel = channel;
        this.msgTypes = [];
        this.intervalFn = intervalFn;
        this.source = source;
    }
    withConstantInterval(interval) {
        this.intervalFn = () => interval;
        return this;
    }
    connectTo(msgType) {
        if (this.msgTypes.indexOf(msgType) === -1) this.msgTypes.push(msgType);
        return this;
    }
    send() {
        if (this.source.hasNext()) {
            this.msgTypes.forEach(msgType => this.channel.push(msgType, this.source.next()));
        }
    }
    scheduleNext() {
        setTimeout(function() {
            this.send();
            this.scheduleNext();
        }.bind(this), this.intervalFn());
    }
    start() {
        this.scheduleNext();
        return this;
    }
}
