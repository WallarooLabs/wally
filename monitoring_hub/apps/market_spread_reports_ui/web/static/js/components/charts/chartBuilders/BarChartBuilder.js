import d3 from "d3";
import {xComparator, yComparator} from "../../../util/Comparators.js";
import ReactFauxDOM from "react-faux-dom";
import {partition} from "../../../util/ListHelpers.js";
import ScaleBuilder from "./ScaleBuilder.js";

export default class BarChartBuilder {
    constructor(options) {
        this.w = options.w || 500;
        this.h = options.h || 300;
        this.padding = 70; //options.padding || 35;

        this.xTicks = options.xTicks || 10;
        this.yTicks = options.yTicks || 10;
        this.barColor = options.barColor || "steelblue";
        this.yLeftLabel = options.yLeftLabel || "";
        this.yRightLabel = options.yRightLabel || "";

        this.xTickFormatter = options.xTickFormatter || (d => d);
        this.xValueTransformer = options.xValueTransformer || (d => d);
        this.yLeftValueFormatter = options.yLeftValueFormatter || (d => d);
        this.yLeftValueTransformer = options.yLeftValueTransformer || (d => d);
        this.yRightValueFormatter = options.yRightValueFormatter || (d => d);
        this.yRightValueTransformer = options.yRightValueTransformer || (d => d);
        this.xLogScale = options.xLogScale || false;

        this.yLeftDomain = options.yLeftDomain || null;

        this.xTickValues = options.xTickValues || null;
    }

    buildWith(data, options) {
        // data should come in the form of a list of maps of the form {x: ?, y: ?}

        if (data.isEmpty()) return this.emptyChart();

        let barData = data.get("bars");

        if (!barData || barData.isEmpty()) return this.emptyChart();

        const xMax = (options.xMax) ? options.xMax : barData.max(xComparator).get("x");
        const xMin = (options.xMin) ? options.xMin : barData.min(xComparator).get("x");
        const yMax = (options.xMax) ? options.xMax : barData.max(yComparator).get("y");
        const yMin = (options.xMin) ? options.xMin : barData.min(yComparator).get("y");

        const xTicks = this.xTicks;

        let yLeftDomain;
        if (this.yLeftDomain) {
            yLeftDomain = this.yLeftDomain;
        } else {
            yLeftDomain = [0, yMax];
        }

        //Create SVG in FauxDOM element
        const svg = d3.select(ReactFauxDOM.createElement("div"))
            .append("svg")
            .attr("width", this.w)
            .attr("height", this.h);

        let xScale;
        if (this.xLogScale) {
            xScale = new ScaleBuilder()
                .basedOn(d3.scale.log()
                    .domain([xMin, xMax * 10])
                    .range([this.padding, this.w - this.padding * 2])
                    .nice())
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

        let xTickValues = this.xTickValues || xTicks;

        let xAxis = d3.svg.axis()
                        .scale(xScale)
                        .orient("bottom")
                        .ticks(xTicks)
                        .tickValues(xTickValues)
                        .tickFormat(this.xTickFormatter)
                        .tickPadding(15);

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
        const yScale = new ScaleBuilder()
            .basedOn(d3.scale.linear()
                .domain(yLeftDomain)
                .range([this.h - this.padding, this.padding]))
            .withTransformer(this.yLeftValueTransformer)
            .build();

        const yAxis = d3.svg.axis()
            .scale(yScale)
            .orient("left")
            .ticks(this.yTicks)
            .tickSize(0)
            .tickPadding(10)
            .tickFormat(this.yLeftValueFormatter);

        //const lineForLeftAxis = d3.svg.line()
        //    .x(function(d) { return this.xValueTransformer(xScale(d.get("x"))); }.bind(this))
        //    .y(function(d) { return this.yLeftValueTransformer(yLeftScale(d.get("y"))); }.bind(this))
        //    .interpolate("monotone");
        //
        //svg.append("svg:path")
        //    .attr("d", lineForLeftAxis(lineData))
        //    .style("stroke", this.yLeftLineColor);

        let w = this.w;
        let h = this.h;

        let barPadding = 1;
        let padding = this.padding;

        var x = d3.scale.ordinal()
            .rangeRoundBands([this.padding, this.w - this.padding * 2], 0.01);
        //
        var y = d3.scale.linear()
            .rangeRound([this.h - this.padding, this.padding]);

        x.domain([xMin, xMax]);
        y.domain([0, yMax]);

        let scaleEnd = w - (this.padding * 3);

        //svg.append("g")
        //    .attr("class", "x axis")
        //    .attr("transform", "translate(0," + this.h + ")")
        //    .call(xAxis);
        ////
        //svg.append("g")
        //    .attr("class", "y axis")
        //    .call(yAxis)
        //    .append("text")
        //    .attr("transform", "rotate(-90)")
        //    .attr("y", 6)
        //    .attr("dy", ".71em")
        //    .style("text-anchor", "end")
        //    .text("Frequency");


        svg.selectAll(".bar")
            .data(barData.toArray())
            .enter().append("rect")
            .attr("class", "bar_fill")
            .attr("x", function(d, i) { return padding + (scaleEnd/barData.size * i); })
            .attr("width", scaleEnd / barData.size - barPadding)
            .attr("y", function(d) {
                return (h - padding) - (d.get("y") / 100 * (h - padding * 2));
            })
            .attr("height", function(d) { 
                return d.get("y") / 100 * (h - padding * 2);
            });


        //svg.selectAll(".bar")
        //    .data(barData.toArray())
        //    .enter().append("rect")
        //    .attr("class", "bar_fill")
        //    .attr("x", function(d) { return x(d.get("x")); })
        //    .attr("width", 10)// x.rangeBand())
        //    .attr("y", function(d) { return y(d.get("y")); })
        //    .attr("height", function(d) { return h - y(d.get("y")); });

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
            .call(yAxis);

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


        return svg.node().toReact();
    }
}
