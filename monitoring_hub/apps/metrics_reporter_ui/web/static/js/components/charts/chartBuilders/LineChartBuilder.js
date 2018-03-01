import d3 from "d3";
import ReactFauxDOM from "react-faux-dom";
import {partition} from "../../../util/ListHelpers.js";
import {xComparator, yComparator} from "../../../util/Comparators.js";
import ScaleBuilder from "./ScaleBuilder.js";

export default class LineChartBuilder {
    constructor(options) {
        this.w = options.w || 500;
        this.h = options.h || 300;
        this.padding = 70; //options.padding || 35;
        this.yAxes = options.yAxes || 1;

        this.xTicks = options.xTicks || 0;
        this.yTicks = options.yTicks || 10;
        this.yLeftLineColor = options.yLeftLineColor || "steelblue";
        this.yRightLineColor = options.yRightLineColor || "red";
        this.yLeftLabel = options.yLeftLabel || "";
        this.yRightLabel = options.yRightLabel || "";

        this.xTickFormatter = options.xTickFormatter || (d => d);
        this.xValueTransformer = options.xValueTransformer || (d => d);
        this.yLeftValueFormatter = options.yLeftValueFormatter || (d => d);
        this.yLeftValueTransformer = options.yLeftValueTransformer || (d => d);
        this.yRightValueFormatter = options.yRightValueFormatter || (d => d);
        this.yRightValueTransformer = options.yRightValueTransformer || (d => d);
        this.xLogScale = options.xLogScale || false;
        this.xPowScale = options.xPowScale || false;
        this.xPowScaleExponent = options.xPowScaleExponent || 1;

        this.yLeftDomain = options.yLeftDomain || null;

        this.interpolation = options.interpolation || "monotone";
    }

    hasRightAxis() {
        return this.yAxes > 1;
    }
    buildWith(data, options) {
        if (data.isEmpty()) return this.emptyChart();

        const hasRightAxis = this.hasRightAxis() && data.has("line2") && !data.get("line2").isEmpty();

        let lineData = data.get("line");
        let line2Data;
        if (this.hasRightAxis()) {
            line2Data = data.get("line2");
        }

        if (!lineData || lineData.isEmpty()) return this.emptyChart();

        let threshold = options.thresholdValue;
        const xMax = (options.xMax) ? options.xMax : lineData.max(xComparator).get("x");
        const xMin = (options.xMin) ? options.xMin : lineData.min(xComparator).get("x");

        // let yLeftMax = lineData.max(yComparator).get("y");
        let yLeftMax = lineData.sort((a,b) => a.get("y") - b.get("y")).get(-1).get("y");

        if (threshold) {
            yLeftMax = Math.max((4/3) * threshold, yLeftMax);
        }

        let yLeftDomain;
        if (this.yLeftDomain) {
            yLeftDomain = this.yLeftDomain;
        } else {
            yLeftDomain = [0, yLeftMax];
        }

        let yRightMax;
        if (hasRightAxis) {
            yRightMax = line2Data.max(yComparator).get("y");
        }


        //Create SVG in FauxDOM element
        const svg = d3.select(ReactFauxDOM.createElement("div"))
            .append("svg")
            .attr("width", this.w)
            .attr("height", this.h);

        let xScale;
        let xAxis;
        if (this.xLogScale) {
            xScale = new ScaleBuilder()
                .basedOn(d3.scale.log()
                            .domain([xMin, xMax])
                            .range([this.padding, this.w - this.padding * 2])
                            .nice())
                .withTransformer(this.xValueTransformer)
                .build();
        } else if (this.xPowScale) {
            xScale = new ScaleBuilder()
                .basedOn(d3.scale.pow()
                    .domain([xMin, xMax])
                    .range([this.padding, this.w - this.padding * 2])
                    .exponent(this.xPowScaleExponent))
                .withTransformer(this.xValueTransformer)
                .build();
        } else {
            xScale = new ScaleBuilder()
                .basedOn(d3.scale.linear()
                        .domain([xMin, xMax])
                        .range([this.padding, this.w - this.padding * 2]))
                .withTransformer(this.xValueTransformer)
                .build();

        }

        xAxis = d3.svg.axis()
                        .scale(xScale)
                        .orient("bottom")
                        .ticks(this.xTicks)
                        .tickValues(this.xTicks)
                        .tickFormat(this.xTickFormatter);

        svg.append("g")
            .attr("class", "axis")
            .attr("transform", "translate(0," + (this.h - this.padding) + ")")
            .call(xAxis)
                .selectAll("text")
                .style("text-anchor", "end")
                .attr("dx", "-.8em")
                .attr("dy", ".15em")
                .attr("transform", "rotate(-65)" );

        svg.selectAll(".tick")
            .filter(function (d, i) { return i === 0 || i === this.xTicks;  }.bind(this))
            .remove();


        //Define Y axes
        ////Left Y Axis
        const yLeftScale = new ScaleBuilder()
            .basedOn(d3.scale.linear()
                .domain(yLeftDomain)
                .range([this.h - this.padding, this.padding]))
            .withTransformer(this.yLeftValueTransformer)
            .build();

        const yAxisLeft = d3.svg.axis()
            .scale(yLeftScale)
            .orient("left")
            .ticks(this.yTicks)
            .tickSize(0)
            .tickPadding(10)
            .tickFormat(this.yLeftValueFormatter);

        const lineForLeftAxis = d3.svg.line()
            .x(function(d) { return this.xValueTransformer(xScale(d.get("x"))); }.bind(this))
            .y(function(d) { return this.yLeftValueTransformer(yLeftScale(d.get("y"))); }.bind(this))
            .interpolate(this.interpolation);

        svg.append("svg:path")
            .attr("d", lineForLeftAxis(lineData))
            .style("stroke", this.yLeftLineColor);

        ////Label
        svg.append("text")
            .attr("transform", "rotate(-90)")
            .attr("y", 0)
            .attr("x", 0 - this.h / 2)
            .attr("dy", "1em")
            .attr("fill", this.yLeftLineColor)
            .style("text-anchor", "middle")
            .text(this.yLeftLabel);

        svg.append("g")
            .attr("class", "axis")
            .attr("transform", "translate(" + this.padding + ",0)")
            .call(yAxisLeft);

        //Right Y Axis (if it exists)
        if (hasRightAxis) {
            const yRightScale = new ScaleBuilder()
                .basedOn(d3.scale.linear()
                    .domain([0, yRightMax])
                    .range([this.h - this.padding, this.padding]))
                .withTransformer(this.yRightValueTransformer)
                .build();

            const yAxisRight = d3.svg.axis()
                .scale(yRightScale)
                .orient("right")
                .ticks(this.yTicks)
                .tickSize(0)
                .tickPadding(10)
                .tickFormat(this.yRightValueFormatter);

            const lineForRightAxis = d3.svg.line()
                .x(function(d) { return this.xValueTransformer(xScale(d.get("x"))); }.bind(this))
                .y(function(d) { return this.yRightValueTransformer(yRightScale(d.get("y"))); }.bind(this))
                .interpolate(this.interpolation);

            svg.append("svg:path")
                .attr("d", lineForRightAxis(line2Data))
                .style("stroke", this.yRightLineColor);

            ////Label
            svg.append("text")
                .attr("transform", "rotate(-90)")
                .attr("y", this.w - this.padding - 20)
                .attr("x", 0 - this.h / 2)
                .attr("dy", "1em")
                .attr("fill", this.yRightLineColor)
                .style("text-anchor", "middle")
                .text(this.yRightLabel);

            svg.append("g")
                .attr("class", "axis")
                .attr("transform", "translate(" + (this.w - this.padding * 2) + ",0)")
                .call(yAxisRight);

        }

        if(threshold) {
            svg.append('line')
                .attr('x1', xScale(xMin))
                .attr('y1', yLeftScale(threshold))
                .attr('x2', xScale(xMax))
                .attr('y2', yLeftScale(threshold))
                .attr('class', 'zeroline');

            svg.append('text')
                .attr('x', xScale(xMax))
                .attr('y', yLeftScale(threshold))
                .attr('dy', '1em')
                .attr('text-anchor', 'end')
                .text(options.thresholdLabel)
                .attr('class', 'threshold-label');
        }

        return svg.node().toReact();
    }
    emptyChart() {
        //Define X axis
        const xScale = d3.scale.linear()
            .domain([0, 10])
            .range([this.padding, this.w - this.padding * 2]);

        const svg = d3.select(ReactFauxDOM.createElement("div"))
            .append("svg")
            .attr("width", this.w)
            .attr("height", this.h);

        const xAxis = d3.svg.axis()
            .scale(xScale)
            .orient("bottom")
            //.ticks(this.xTicks)
            .ticks(0)
            .tickSize(0)
            .tickPadding(10);

        svg.append("g")
            .attr("class", "axis")
            .attr("transform", "translate(0," + (this.h - this.padding) + ")")
            .call(xAxis)
            .selectAll("text")
            .style("text-anchor", "end")
            .attr("dx", "-.8em")
            .attr("dy", ".15em")
            .attr("transform", "rotate(-65)");

        svg.selectAll(".tick")
            .filter(function (d, i) {
                return i === 0 || i === this.xTicks;
            }.bind(this))
            .remove();


        const yScale = d3.scale.linear()
            .domain([0, 0])
            .range([this.h - this.padding, this.padding]);

        const yAxisLeft = d3.svg.axis()
            .scale(yScale)
            .orient("left")
            .ticks(this.yTicks)
            .tickSize(0)
            .tickPadding(10);

        svg.append("g")
            .attr("class", "axis")
            .attr("transform", "translate(" + this.padding + ",0)")
            .call(yAxisLeft);

        ////Label
        svg.append("text")
            .attr("transform", "rotate(-90)")
            .attr("y", 0)
            .attr("x", 0 - this.h / 2)
            .attr("dy", "1em")
            .attr("fill", this.yLeftLineColor)
            .style("text-anchor", "middle")
            .text(this.yLeftLabel);

        if (this.hasRightAxis()) {
            const yAxisRight = d3.svg.axis()
                .scale(yScale)
                .orient("right")
                .ticks(this.yTicks)
                .tickSize(0)
                .tickPadding(10);

            svg.append("g")
                .attr("class", "axis")
                .attr("transform", "translate(" + (this.w - this.padding * 2) + ",0)")
                .call(yAxisRight);

            ////Label
            svg.append("text")
                .attr("transform", "rotate(-90)")
                .attr("y", this.w - this.padding - 20)
                .attr("x", 0 - this.h / 2)
                .attr("dy", "1em")
                .attr("fill", this.yRightLineColor)
                .style("text-anchor", "middle")
                .text(this.yRightLabel);
        }

        return svg.node().toReact();
    }
}
