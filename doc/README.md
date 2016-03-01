# Buffy Docs

Here you'll find a variety of sources for getting started working
on the Buffy project. 

The first thing you should do is read [Buffy for Engineers](buffy-for-engineers.asciidoc), 
to get a sense for the problems we're trying to solve and our general 
strategies for solving them.

## Buffy Theory

For a list of papers and talks to get you started thinking about 
stream processing, distributed systems, and idempotent data
structures, check out [Sendence Links](sendence-links.org).

For a technical overview of our Flow Notation and our approach to 
tracing, read [Flows and Traces](flows-and-traces.pdf).

For a discussion of messages and latency, check out 
[Messages and Latency](https://docs.google.com/document/d/13X7wWh025bz9skuCU5Oi1zyMdWTbFn58oFEArTKwS8A/edit).

## TLA+

We are using [TLA+](http://research.microsoft.com/en-us/um/people/lamport/tla/tla.html) 
to write specifications for Buffy.

The TLA+ Toolbox is necessary for the Model Checker and Proof Manager. 
Take a look at our [TLA+ Toolbox guide](tla-toolbox.md).