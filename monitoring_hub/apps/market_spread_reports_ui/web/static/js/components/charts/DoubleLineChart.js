import React from "react";
import ReactDOM from "react-dom";
import TimeIntervalLineChartBuilder from "./chartBuilders/TimeIntervalLineChartBuilder.js";

export default class DoubleLineChart extends React.Component {
    constructor(props) {
        super(props);
        this.chartBuilder = new TimeIntervalLineChartBuilder({
            w: this.props.w,
            h: this.props.h,
            padding: this.props.padding,
            yAxes: 2,
            xTicks: this.props.xTicks,
            yTicks: this.props.yTicks,
            interval: this.props.interval,
            yLeftLineColor: this.props.colorForLine1,
            yLeftLabel: this.props.yLeftLabel,
            yRightLineColor: this.props.colorForLine2,
            yRightLabel: this.props.yRightLabel,
            xTickFormatter: this.props.xTickFormatter,
            xValueTransformer: this.props.xValueTransformer,
            yLeftValueFormatter: this.props.yLeftValueFormatter,
            yRightValueFormatter: this.props.yRightValueFormatter,
            yLeftValueTransformer: this.props.yLeftValueTransformer,
            yRightValueTransformer: this.props.yRightValueTransformer,
            thresholdValue: this.props.thresholdValue,
            thresholdLabel: this.props.thresholdLabel
        });
    }
    render() {
        return this.chartBuilder.buildWith(this.props.data, {
            thresholdValue: this.props.thresholdValue,
            thresholdLabel: this.props.thresholdLabel
        });
    }
}
