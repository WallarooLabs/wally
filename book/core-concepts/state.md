# State

The expectation with Wallaroo is that most applications will be stateful. Understanding how Wallaroo handles state is key to being able to design effective Wallaroo applications. In this section, we're going to take you through how state works in Wallaroo and what advantages this brings.

## Transactions in Wallaroo

Transactions are awesome. Using a data management system that features transactions makes our lives as programmers much easier. Transactions provide certain guarantees about how data will be updated that make it easier to reason about our code, easier to understand what our code will do. This is particularly true when we are talking about concurrent operations.

It's often quite easy to understand what our code is doing if we only have a single thread. Everything will happen in a nice linear, serial fashion. Sadly, the world in which our code runs isn't serial, it's concurrent. Many different operations happening at one time. Transactions, in part, allow us to think about how our code is updating data as though the updates were happening one at a time, that is in a serial fashion.

Wallaroo doesn't have transactions in the traditional database sense. However, we do have a means of providing similar guarantees. Wallaroo allows you to atomically update individual bits of state. To understand how that works and the guarantees that Wallaroo provides, let's dig into how Wallaroo handles that.

## Wallaroo and State

The simplest thing we could do to make it easy to reason about state is to lock all the state in your application. Only allowing a single update or read at a time. It would make Wallaroo applications very easy to reason about. It would also make them incredibly slow.

What we've done instead is to allow you to break your state down into more discrete entities we call "state objects". All reads/writes of a given state object are guaranteed to happen in a serial fashion. No more than one thread will ever access a given state object at a time.

This makes it easy to reason about state within Wallaroo. All the wonderful reasoning benefits we get from transactions apply in Wallaroo, except that rather than being across an entire database, it's across individual state objects.

So what is a state object? Let's explain via an example. Imagine we are writing an application that keeps track of the latest price for different stock in the stock market. Each of the stocks would become a state object. It's the discrete unit of atomicity that we want to be able to safely update. We want to make sure only one thread at a time is updating IBM, but, we also want to go fast, so it's ok if APPL or AMZN is being updated at the same time.

Wallaroo allows you to define your own state objects that match your domain. For example, our example application might define a state object as:

{% codetabs name="Python", type="py" -%}
class Stock(object):
    def __init__(self, symbol, price):
        self.symbol = symbol
        self.price = price
{%- language name="Go", type="go" -%}
type Stock struct {
  Symbol string
  Price float64
}
{%- endcodetabs %}

State objects can be arbitrarily complex. Our example is two fields. If your application required it, you could build a deeply nested series of objects.

## Wallaroo, state, and parallelization

In our stock market example, we can read from and write to each state object independently. Our state objects are a unit of parallelization. If we have 3,000 different state objects and 3,000 CPUS then we can update all our state objects concurrently. Odds are, we are going to have more state objects than we have CPUs. Wallaroo handles all parallelization and routing of messages to state objects.

The Wallaroo API features a concept called a "partitioning function" that allows you to examine a message indicate how it should be routed. For example, imagine a message in our stock market application is:

```json
{
"symbol": "IBM",
"price": "169.53"
}
```

Our partitioning function would take a message as input and return `IBM` as output. This would, in turn, be used by Wallaroo to route the message.

## Conclusion

Wallaroo gives you serialized access to state. By properly partitioning your state along transactional boundaries, you can parallelize access to independent pieces of state. Wallaroo takes care of this parallelization for you, all you have to do is give it a function that can tell it which pieces of state should be accessed for a particular message.
