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
        case "100.0":
            return "> 10 s";
        case "10.0":
            return "< 10 s";
        case "10":
            return "< 10 s"; 
        case "1":
            return "< 1 s";
        case "1.0":
            return "< 1 s";
        case "0.1":
            return "< 100 ms";
        case "0.01":
            return "< 10 ms";
        case "0.001":
            return "< 1 ms";
        case "0.0001":
            return "< 100 μs";
        case "0.00001":
            return "< 10 μs";
        case "0.000001":
            return "< 1 μs";
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
