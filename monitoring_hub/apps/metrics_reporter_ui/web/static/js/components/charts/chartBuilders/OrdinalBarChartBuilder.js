import d3 from "d3";
import {xComparator, yComparator} from "../../../util/Comparators.js";
import ReactFauxDOM from "react-faux-dom";
import {partition} from "../../../util/ListHelpers.js";
import ScaleBuilder from "./ScaleBuilder.js";

export default class OrdinalBarChartBuilder {
    constructor(options) {
        this.w = options.w || 500;
        this.h = options.h || 300;
        this.padding = 70; //options.padding || 35;

        this.xTicks = options.xTicks || 10;
        this.yTicks = options.yTicks || 10;
        this.barColor = options.barColor || "steelblue";
        this.yLeftLabel = options.yLeftLabel || "";
        this.yLabelColor = options.yLabelColor || "steelblue";
        this.yRightLabel = options.yRightLabel || "";

        this.xTickFormatter = options.xTickFormatter || (d => d);
        this.xValueTransformer = options.xValueTransformer || (d => d);
        this.yLeftValueFormatter = options.yLeftValueFormatter || (d => d);
        this.yLeftValueTransformer = options.yLeftValueTransformer || (d => d);
        this.yRightValueFormatter = options.yRightValueFormatter || (d => d);
        this.yRightValueTransformer = options.yRightValueTransformer || (d => d);

        this.yLeftDomain = options.yLeftDomain || null;

        this.xTickValues = options.xTickValues || null;
    }

    buildWith(data, options) {
        // data should come in the form of a list of maps of the form {x: ?, y: ?}

        if (data.isEmpty()) return this.emptyChart();

        let barData = data.get("bars");

        if (!barData || barData.isEmpty()) return this.emptyChart();

        const xTicks = this.xTicks;
        let xTickValues = this.xTickValues || xTicks;

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

        let xScale = d3.scale.ordinal()
                .rangeBands([this.padding, this.w - this.padding * 2], 0.01, 0)
                .domain(barData.toArray().map(function(d) { return d.get("x"); }));

        const xAxis = d3.svg.axis()
                    .scale(xScale)
                    .orient("bottom")
                    .ticks(xTicks)
                    // .tickValues(xTickValues)
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

        // svg.selectAll(".tick")
        //     .filter(function (d, i) { return i === 0 || i === this.xTicks;  }.bind(this))
        //     .remove();

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

        let w = this.w;
        let h = this.h;

        let barPadding = 1;
        let padding = this.padding;

        let scaleEnd = w - (this.padding * 3);

        let scaleCopy = d3.scale.ordinal()
                    .domain(barData.toArray().map(function(d) { return d.get("x"); }))
                    .rangeBands([this.padding, this.w - this.padding * 2], 0.01, 0);


        svg.selectAll(".bar")
            .data(barData.toArray())
            .enter().append("rect")
            .attr("class", "bar_fill")
            .attr("fill", this.barColor)
            .attr("x", function(d) { return xScale(d.get("x")); })
            .attr("width", xScale.rangeBand() - 1)
            .attr("y", function(d) {
                return (h - padding - 1) - (d.get("y") / 100 * (h - padding * 2));
            })
            .attr("height", function(d) { 
                return d.get("y") / 100 * (h - padding * 2);
            });


        ////Label
        svg.append("text")
            .attr("transform", "rotate(-90)")
            .attr("y", 0)
            .attr("x", 0 - this.h / 2)
            .attr("dy", "1em")
            .attr("fill", this.yLabelColor)
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
