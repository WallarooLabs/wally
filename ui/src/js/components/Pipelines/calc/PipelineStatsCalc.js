import {Map, List} from "immutable";

const emptyLatencyStats = new Map({
    latencyMinimum: 0,
    latencyMedian: 0,
    latencyMaximum: 0,
    latencyMean: 0
});

const emptyThroughputStats = new Map({
    throughputMinimum: 0,
    throughputMedian: 0,
    throughputMaximum: 0,
    throughputMean: 0
});

function latencyStats(latencies) {
    if (latencies.isEmpty()) return emptyLatencyStats;

    let mid = latencies.get(Math.floor(latencies.size / 2));
    let minLat = Infinity;
    let maxLat = 0;
    let medLat = mid.get("latency");
    let latTotal = 0;
    let runningCount = 0;

    latencies.forEach(b => {
        const lat = b.get("latency");
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        latTotal += lat;
        runningCount += 1;
    });
    return new Map({
        latencyMinimum: minLat,
        latencyMedian: medLat,
        latencyMaximum: maxLat,
        latencyMean: ((runningCount == 0) ? 0 : latTotal / runningCount).toFixed(1)
    });
}

function throughputStats(throughputs) {
    if (throughputs.isEmpty()) return emptyThroughputStats;

    let mid = throughputs.get(Math.floor(throughputs.size / 2));
    let minThr = Infinity;
    let maxThr = 0;
    let medThr = mid.get("throughput");
    let thrTotal = 0;
    let runningCount = 0;

    throughputs.forEach(b => {
        const thr = b.get("throughput");
        if (thr < minThr) minThr = thr;
        if (thr > maxThr) maxThr = thr;
        thrTotal += thr;
        runningCount += 1;
    });
    return new Map({
        throughputMinimum: minThr,
        throughputMedian: medThr,
        throughputMaximum: maxThr,
        throughputMean: ((runningCount == 0) ? 0 : thrTotal / runningCount).toFixed(0)
    });
}

function compileStats(latencies, throughputs) {
    const latStats = latencyStats(latencies);
    const thrStats = throughputStats(throughputs);
    return latStats.concat(thrStats);
}

function combineStats(latencyStats, throughputStats) {
    return new Map()
        .set("latency", Map()
            .set("latency50pctl", latencyStats.get("pctl50"))
            .set("latency75pctl", latencyStats.get("pctl75"))
            .set("latency90pctl", latencyStats.get("pctl90")))
        .set("throughput", Map()
            .set("throughputMinimum", throughputStats.get("min"))
            .set("throughputMedian", throughputStats.get("median"))
            .set("throughputMaximum", throughputStats.get("max")));
}

function compilePercentiles(latencies) {
    const percentiles = [ 
        0.000001, 0.100000, 0.200000,
        0.300000, 0.400000, 0.500000,
        0.550000, 0.600000, 0.650000,
        0.700000, 0.750000, 0.775000,
        0.800000, 0.825000, 0.850000,
        0.875000, 0.887500, 0.900000,
        0.912500, 0.925000, 0.937500,
        0.943750, 0.950000, 0.962500,
        0.968750, 0.971875, 0.975000,
        0.978125, 0.981250, 0.984375,
        0.985938, 0.987500, 0.989062,
        0.990625, 0.992188, 0.992969,
        0.993750, 0.994531, 0.995313,
        0.996094, 0.996484, 0.996875,
        0.997266, 0.997656, 0.998047,
        0.998242, 0.998437, 0.998633,
        0.998828, 0.999023, 0.999121,
        0.999219, 0.999316, 0.999414,
        0.999512, 0.999561, 0.999609,
        0.999658, 0.999707, 0.999756,
        0.999780, 0.999805, 0.999829,
        0.999854, 0.999878, 0.999890,
        0.999902, 0.999915, 0.999927,
        0.999939, 0.999945, 0.999951,
        0.999957, 0.999963, 0.999969,
        0.999973, 0.999976, 0.999979,
        0.999982, 0.999985, 0.999986,
        0.999988, 0.999989, 0.999991,
        0.999992, 0.999993, 0.999994,
        0.999995, 0.999996, 0.999997,
        0.999998, 0.999999
    ];
    let percentileList = new List();
    // let percentileMap = new Map();
    percentiles.forEach(p => {
        const valAtPercentile = percentile(latencies, p);
        let percentileMap = new Map({
            "percentile": p,
            "value": valAtPercentile
        });
        // const valAtPercentile = percentile(latencies, p);
        // percentileMap = percentileMap.set(p, valAtPercentile);
        percentileList = percentileList.push(percentileMap);
    });
    return percentileList;
}

function percentile(latencies, p) {
    if (latencies.size === 0) return 0;
    if (p <= 0) return latencies.first().get("latency");
    if (p >= 1) return latencies.last().get("latency");

    const index = latencies.size * p,
          lower = Math.floor(index),
          upper = lower + 1,
          weight = index % 1;

    if (upper >= latencies.size) return latencies.get(lower).get("latency");
    return latencies.get(lower).get("latency") * (1 - weight) + latencies.get(upper).get("latency") * weight; 
}

export default {
    latencyStats: latencyStats,
    throughputStats: throughputStats,
    compileStats: compileStats,
    combineStats: combineStats,
    compilePercentiles: compilePercentiles
}