export default class ScaleBuilder {
    constructor() {
        this.transformer = d => d;
        this.baseScale = null;
    }
    
    withTransformer(transformer) {
        this.transformer = transformer;
        return this;
    }

    basedOn(baseScale) {
        this.baseScale = baseScale;
        return this;
    }
    
    build() {
        const transformer = this.transformer;

        function transformed(base) {
            const that = this;
            let baseScale = base ? base : d3.scale.linear();

            function scale(x) {
                return transformer(baseScale(x));
            }

            scale.domain = function(x) {
                if (!arguments.length) return baseScale.domain();
                baseScale.domain(x);
                return scale;
            };

            scale.range = function(y) {
                if (!arguments.length) return baseScale.range();
                baseScale.range(y);
                return scale;
            };

            scale.copy = function() {
                return transformed(baseScale.copy());
            };

            scale.invert = function(x) {
                return baseScale.invert(x);
            };

            scale.nice = function(m) {
                baseScale = baseScale.nice(m);
                return scale;
            };

            scale.ticks = function(m) {
                return baseScale.ticks(m);
            };


            scale.tickFormat = function(m, Format) {
                return baseScale.tickFormat(m, Format);
            };

            return scale;
        }

        return transformed(this.baseScale);
    }
}