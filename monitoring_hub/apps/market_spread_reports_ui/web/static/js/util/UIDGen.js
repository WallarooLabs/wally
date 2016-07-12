export default class UIDGen {
    constructor(start) {
        this.count = start || 0;
    }
    next() {
        return this.count++;
    }
}