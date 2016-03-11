import LineChartBuilder from "./LineChartBuilder.js";
import {partition} from "../../../util/ListHelpers.js";
import {xComparator} from "../../../util/Comparators.js";
import {Map} from "immutable";

function addMinIfNeeded(data, xMin) {
    const part = partition(data, function (d) {
        return xMin < d.get("x");
    }.bind(this));
    const displayData = part.get(0);
    const filtered = part.get(1);

    if (filtered.size > 0) {
        const minDisplayElement = filtered.max(xComparator);
        const toAdd = minDisplayElement.set("x", xMin);
        return displayData.unshift(toAdd);
    } else {
        return displayData;
    }
}

export default class TimeIntervalLineChartBuilder {
    constructor(options) {
        this.interval = options.interval;

        this.lineChartBuilder = new LineChartBuilder(options);
    }
    buildWith(data, options) {
        if (data.isEmpty()) return this.lineChartBuilder.emptyChart();

        const hasLine2 = data.has("line2") && !data.get("line2").isEmpty();

        let lineData = data.get("line");
        let line2Data;
        if (hasLine2) {
            line2Data = data.get("line2");
        }

        if (!lineData || lineData.isEmpty()) return this.lineChartBuilder.emptyChart();

        let xMax;
        xMax = lineData.max(xComparator).get("x");
        if (hasLine2) {
            xMax = Math.max(xMax, line2Data.max(xComparator).get("x"));
        }

        const xMin = ((xMax - this.interval) > 0) ? (xMax - this.interval) : 0;
        const buildOptions = {
            xMin: xMin,
            xMax: xMax,
            thresholdValue: options.thresholdValue,
            thresholdLabel: options.thresholdLabel
        };

        const line1 = addMinIfNeeded(lineData, xMin);
        let displayData = new Map({
            line: line1
        });

        let line2;
        if (hasLine2) {
            line2 = addMinIfNeeded(line2Data, xMin);
            displayData = displayData.set("line2", line2)
        }

        return this.lineChartBuilder.buildWith(displayData, buildOptions);
    }
}