package buffy;

public interface Computation<In, Out> {
	Out execute(In in, Buffy buffy);
}