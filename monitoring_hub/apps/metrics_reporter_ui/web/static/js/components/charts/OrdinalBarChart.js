import React from "react";
import ReactDOM from "react-dom";
import OrdinalBarChartBuilder from "./chartBuilders/OrdinalBarChartBuilder.js";
import Immutable from "immutable";

export default class OrdinalBarChart extends React.Component {
    constructor(props) {
        super(props);
        this.chartBuilder = new OrdinalBarChartBuilder({
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
            xPowScale: this.props.xPowScale,
            xPowScaleExponent: this.props.xPowScaleExponent,
            xOrdinalScale: this.props.xOrdinalScale,
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
