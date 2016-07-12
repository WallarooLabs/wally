import React from "react";
import ReactDOM from "react-dom";
import BarChartBuilder from "./chartBuilders/BarChartBuilder.js";
import Immutable from "immutable";

export default class BarChart extends React.Component {
    constructor(props) {
        super(props);
        this.chartBuilder = new BarChartBuilder({
            w: this.props.w,
            h: this.props.h,
            padding: this.props.padding,
            xTicks: this.props.xTicks,
            yTicks: this.props.yTicks,
            barColor: this.props.barColor,
            yLeftLabel: this.props.yLeftLabel,
            xTickFormatter: this.props.xTickFormatter,
            xValueTransformer: this.props.xValueTransformer,
            yLeftValueFormatter: this.props.yLeftValueFormatter,
            yLeftValueTransformer: this.props.yLeftValueTransformer,
            xLogScale: this.props.xLogScale,
            yLeftDomain: this.props.yLeftDomain,
            xTickValues: this.props.xTickValues
        });
    }
    shouldComponentUpdate(nextProps, nextState) {
        return !Immutable.is(this.props.data, nextProps.data);
    }
    render() {
        return this.chartBuilder.buildWith(this.props.data, {});
    }
}
