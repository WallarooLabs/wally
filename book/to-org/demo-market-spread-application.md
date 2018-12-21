# Demo - Market Spread Application

We developed the Market Spread Demo to showcase various aspects of Wallaroo.

In an electronic trading environment algorithms execute trades at blazing fast speeds.  Multiple systems are interacting with each other and making trading decisions based on the data available.  Given such a complex environment, mistakes can happen and a variety of safeguards are put in place to prevent problems.  One such safeguard is to not allow a trade to execute if unusual activity is detected in the trading of a particular instrument.  

In this example application we look for irregularities is market data bid and ask prices.  An instrument is considered a risky trade if there difference between the bid and ask price exceeds a certain amount.

This application is made up of two pipelines; NBBO and Orders.

The first, NBBO, is a feed of simulated market data bid and ask prices for various instruments.  The data feed is sending 100k messages per second for 3,000 different trading symbols.  State for a particular symbol is updated each time a new bid and ask price is received.  Additionally, a flag is set indicating a trade risk threshold violation.

The second, "Orders," contains simulated orders.  The state of the symbol in the order request is checked to see if it currently violates the risk threshold.  If it does the order is considered rejected and logged.

A custom report is available of the rejected orders log.  This updates in real-time, displaying detail about every rejected order.  You will see an unusual number of violations in the demo compared to an actual trading situation.  Many rejected orders are created to allow users to get a sense of the features.


<img src="\images\market-spread-overview.png" width="1000px">
