import Moment from "moment";
import {toMinutes, toSeconds} from "./Duration.js";
import {cleanTrailing} from "./Precision.js";

function throughputInThousands(throughputs) {
    return throughputs.map(d => {
        return d.set("throughput", d.get("throughput") / 1000);
    });
}

function latencyInMilliseconds(latencies) {
    return latencies.map(d => {
        return d.set("latency", d.get("latency") / 1000);
    });
}

function numberWithCommas(x) {
    return x.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

function formatTime(t) {
    return Moment(t).format("h:mm:ss A");
}

function formatThroughput(thr) {
    if (thr == Infinity) {
        return "0k";
    } else if (thr == "-") {
        return thr;
    }
    return cleanTrailing(thr/1000, 2) + "k";
}

function formatLatency(latency) {
    const latencyInMilliseconds = cleanTrailing(latency/1000, 2).toFixed(2);
    if (latency == "-") {
        return latency;
    } else if (latencyInMilliseconds < 0.01){
        return "< 0.01"
    } else {
        return latencyInMilliseconds;
    }
}

function displayInterval(interval) {
    if (toMinutes(interval) == 1) {
        return toMinutes(interval) + " Minute"
    } else if (toMinutes(interval) > 1) {
        return toMinutes(interval) + " Minutes"
    } else {
        return toSeconds(interval) + " Seconds"
    }
}

function labelForLimit(limit) {
    if (limit) {
        return "$" + numberWithCommas(limit) + " limit";
    } else {
        return "";
    }
}

function formatOrderId(orderId) {
    if (orderId.includes("-")) {
        return orderId.split("-")[1];
    } else {
        return orderId;
    }
}

export default {
    throughputInThousands: throughputInThousands,
    numberWithCommas: numberWithCommas,
    formatTime: formatTime,
    formatThroughput: formatThroughput,
    formatLatency: formatLatency,
    displayInterval: displayInterval,
    labelForLimit: labelForLimit,
    latencyInMilliseconds: latencyInMilliseconds,
    formatOrderId: formatOrderId
}
