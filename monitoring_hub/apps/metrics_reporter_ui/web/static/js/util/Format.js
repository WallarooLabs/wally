import Moment from "moment";
import {toMinutes, toSeconds} from "./Duration.js";
import {cleanTrailing} from "./Precision.js";

function throughputInThousands(throughputs) {
    return throughputs.map(d => {
        return d.set("total_throughput", d.get("total_throughput") / 1000);
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

function formatLatencyBin(bin) {
    switch(bin) {
        case "1":
            return "≤ 1 ns";
        case "1024":
            return "≤ 1 μs";
        case "524288":
            return "≤ 0.5 ms";
        case "1048576":
            return "≤ 1 ms";
        case "2097152":
            return "≤ 2 ms";
        case "4194304":
            return "≤ 4 ms";
        case "8388608":
            return "≤ 8 ms";
        case "16777216":
            return "≤ 17 ms";
        case "33554432":
            return "≤ 34 ms";
        case "67108864":
            return "≤ 67 ms";
        case "134217728":
            return "≤ 134 ms";
        case "1073741824":
            return "≤ 1 s";
        case "18446744073709551616":
            return "≤ Max Bin";
        default:
            return bin;
    }
}

function titleize(str) {
    if (!isUpperCase(str)) {
        return str.toLowerCase().replace(/(?:^|\s|-)\S/g, function (m) {
            return m.toUpperCase();
        });
    } else {
        return str;
    }
}

function isUpperCase(str) {
    return str === str.toUpperCase();
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
    formatOrderId: formatOrderId,
    formatLatencyBin: formatLatencyBin,
    titleize: titleize
}
