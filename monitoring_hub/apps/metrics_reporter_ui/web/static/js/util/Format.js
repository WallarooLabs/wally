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
    } else if (thr > 10000) {
        return cleanTrailing(thr/1000, 0) + "k";
    } else if (thr >= 1000000) {
        return cleanTrailing(thr/1000000, 2) + "m";
    } else {
        return cleanTrailing(thr/1000, 2) + "k";
    }
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

// function formatLatencyBin(bin) {
//     switch(bin) {
//         case "1":
//             return "≤ 1 ns";
//         case "1024":
//             return "≤ 1 μs";
//         case "524288":
//             return "≤ 0.5 ms";
//         case "1048576":
//             return "≤ 1 ms";
//         case "2097152":
//             return "≤ 2 ms";
//         case "4194304":
//             return "≤ 4 ms";
//         case "8388608":
//             return "≤ 8 ms";
//         case "16777216":
//             return "≤ 17 ms";
//         case "33554432":
//             return "≤ 34 ms";
//         case "67108864":
//             return "≤ 67 ms";
//         case "134217728":
//             return "≤ 134 ms";
//         case "1073741824":
//             return "≤ 1 s";
//         case "18446744073709551616":
//             return "≤ Max Bin";
//         default:
//             return bin;
//     }
// }

function formatLatencyBin(bin) {
    switch(bin) {
        case 0:
            return "0";
        case "0":
            return "0";
        case "1":
            return "≤ 1 ns";
        case "2":
            return "≤ 2 ns";
        case "4":
            return "≤ 4 ns";
        case "8":
            return "≤ 8 ns";
        case "16":
            return "≤ 16 ns";
        case "32":
            return "≤ 32 ns";
        case "64":
            return "≤ 64 ns";
        case "128":
            return "≤ 128 ns";
        case "256":
            return "≤ 256 ns";
        case "512":
            return "≤ 512 ns";
        case "1024":
            return "≤ 1 μs";
        case "2048":
            return "≤ 2 μs";
        case "4096":
            return "≤ 4 μs";
        case "8192":
            return "≤ 8 μs";
        case "16384":
            return "≤ 16 μs";
        case "32768":
            return "≤ 32 μs";
        case "65536":
            return "≤ 66 μs";
        case "131072":
            return "≤ 130 μs";
        case "262144":
            return "≤ 260 μs";
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
            return "≤ 16 ms";
        case "33554432":
            return "≤ 34 ms";
        case "67108864":
            return "≤ 66 ms";
        case "134217728":
            return "≤ 134 ms";
        case "268435456":
            return "≤ 260 ms";
        case "536870912":
            return "≤ 0.5 s";
        case "1073741824":
            return "≤ 1 s";
        case "18446744073709551616":
            return "> 1 s";
        default:
            return "> 1 s";
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

export {
    throughputInThousands,
    numberWithCommas,
    formatTime,
    formatThroughput,
    formatLatency,
    displayInterval,
    labelForLimit,
    latencyInMilliseconds,
    formatOrderId,
    formatLatencyBin,
    titleize
}
