import React from "react";
import ReactDOM from "react-dom";
import TimeIntervalLineChartBuilder from "./chartBuilders/TimeIntervalLineChartBuilder.js";

export default class LineChart extends React.Component {
    constructor(props) {
        super(props);
        this.chartBuilder = new TimeIntervalLineChartBuilder({
            w: this.props.w,
            h: this.props.h,
            padding: this.props.padding,
            yAxes: 1,
            xTicks: this.props.xTicks,
            yTicks: this.props.yTicks,
            interval: this.props.interval,
            yLeftLineColor: this.props.colorForLine1,
            yLeftLabel: this.props.yLeftLabel,
            xTickFormatter: this.props.xTickFormatter,
            xValueTransformer: this.props.xValueTransformer,
            yLeftValueFormatter: this.props.yLeftValueFormatter,
            yLeftValueTransformer: this.props.yLeftValueTransformer,
            xLogScale: this.props.xLogScale,
            xPowScale: this.props.xPowScale,
            xPowScaleExponent: this.props.xPowScaleExponent
        });
    }
    shouldComponentUpdate(nextProps, nextState) {
        return this.props.data !== nextProps.data;
    }
    render() {
        return this.chartBuilder.buildWith(this.props.data, {
            thresholdValue: this.props.thresholdValue,
            thresholdLabel: this.props.thresholdLabel
        });
    }
}
