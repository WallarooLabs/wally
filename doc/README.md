# Buffy Docs

Here you'll find a variety of sources for getting started working
on the Buffy project. 

The first thing you should do is read [Buffy for Engineers](buffy-for-engineers.asciidoc) 
to get a sense for the problems we're trying to solve and our general 
strategies for solving them. Once you finish Buffy for Engineers, we suggest
that you check out the [guided tour](#sendence-links-guided-tour) of some of the
content in the [Sendence Links](sendence-links.org) document. The guided tour
should give you a foundation to dig a bit more into some of the concepts from
the Buffy for Engineers document and prepare you to move on. In general, feel
free to picture a tag from Sendence Links and really dig in to a particular
topic. If you find content that you think is relevant/useful, please add it to
Sendence Links.

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

## <a name="sendence-links-guided-tour"></a>Sendence Links Guided Tour

Picking a first paper, video for this guided tour was difficult. Where to start?
Where to start? We decided, that as we are talking about Buffy- a distributed
stream processor that we should start with distributed systems and what that
means.

For an introduction to distributed systems, we suggest you start with Alvaro
Videla's [What we talk about when we talk about distributed systems](http://videlalvaro.github.io/2015/12/learning-about-distributed-systems.html). 
Even if you think you are a distributed systems expert, it can't hurt to watch,
it's a great talk.
 
One of the concepts you are going to hear a lot when working on Buffy is
"how do we avoid coordination?" Coordination in any system, distributed or
otherwise, is a massive performance killer. Peter Bailis does an excellent job
of addressing the general topic in his talk 
[Silence is Golden](https://www.youtube.com/watch?v=EYJnWttrC9k&index=30&list=PLVjgeV_avap2arug3vIz8c6l72rvh9poV).
Hopefully by the time you are done watching it, you'll see how we don't always
need to coordination we think we do in order to maintain consistency in our
systems and will be ready to go explore ideas on the topic.

Let's talk about correctness for a moment. One of the hardest things you will
encounter when dealing with distributed systems is verifying the correctness of
those systems. If you aren't familiar with Kyle Kingsbury's ["Jepsen"](https://aphyr.com/tags/jepsen) 
work, we advise you to check it. Basically Kyle has done it put various
distributed systems under strain and see how well their promised invariants hold
up. Spoiler alert, most don't do particularly well. By the time you have gone
through a few of those posts, you might have a hopeless feeling about
correctness. So, what we do? We'll there's a nugget of hope in a talk a member
of the FoundationDB team did at StrangeLoop a couple years back. 
[Testing Distributed Systems w/ Deterministic Simulation](https://www.youtube.com/watch?v=4fFDFbi3toc) 
is a great, great talk. Our key take away from it, we need to be able design a
system where determism rules. What does that mean? Good question! It's very
hand-wavey. Here's what we ask of you. Check out some of the Jepsen posts then
watch the deterministic simulation talk and imagine what you'd have to do when
designing systems to be able to prove correctness and reliably and easily fix
bugs when you encounter them. 

While we are on the subject of failures, we would be remiss to not point you at
Peter Bailis' talk [When "Worst" is Best](https://www.youtube.com/watch?v=ZGIAypUUwoQ).
The important take away from Peter's talk? By designing for our worst failure
cases, we will in fact reap rewards in our best case scenarios.

Buffy for Engineers brings up CRDTs. CRDTs hold out the promise of distributed,
replicated, *coordination free* data structures. Hopefully by now, you
understand why we are so interested in them. They are a relatively simple
concept wrapped up in a lot of math. Math that not everyone is familiar with.
We have a lot of CRDT related content in the sendence links document. Of
those, we find Sean Cribbs' [The Final Causal Frontier](http://www.ustream.tv/recorded/61448875) 
to be the most beginner friendly. We suggest you start your exploration of
CRDTs there.

If, after reading Buffy for Engineers, you feel you need more of an intro to
dataflows systems, we suggest you purchase a copy of 
[Dataflow and Reactive Programming Systems: A Practical Guide](http://www.amazon.com/Dataflow-Reactive-Programming-Systems-Practical/dp/1497422442/ref=sr_1_1?ie=UTF8&qid=1456849460&sr=8-1&keywords=dataflow). 
It has an unfortunate title (be wary of anything that say "reactive") but is a
surprisingly good, concise read on various types of dataflow systems and will
give you a good basis for exploring the other dataflow content we have
collected.

We could go on and on and on with content we think is really important, but we
are already at a point of "seriously?" so, let's do one more before we send you
off to explore and learn more on your own: 
[End-to-end Arguments in System Design](http://web.mit.edu/Saltzer/www/publications/endtoend/endtoend.pdf).
The abstract does a better job than we ever would in summing up why you should
read it:

> This paper presents a design principle that helps guide placement of functions
> among the modules of a distributed computer system. The principle, called the
> end-to-end argument, suggests that functions placed at low levels of a system
> may be redundant or of little value when compared with the cost of providing
> them at that low level. Examples discussed in the paper include bit error
> recovery, security using encryption, duplicate message suppression, recovery
> from system crashes, and delivery acknowledgement. Low level mechanisms to
> support these functions are justified only as performance enhancements








