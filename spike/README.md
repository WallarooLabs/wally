# spike

Destructive testing for Buffy. 

Ver 0.0.2-sendence

## Types of Destruction

Each spike node can be configured to use one of the following action types. 

1) duplicate  
2) drop  
3) garble  
4) delay  
5) reorder  
6) random -> for each message, selects randomly between destruction types  
7) pass  

## Interfacing with Buffy

      +----------------------------+                      +----------------------------+
      |                            |                      |                            |
      |                            |     +-----------+    |                            |
      |           Buffy            |     |           |    |           Buffy            |
      |   +------+         +------+| +-->|   Spike   |---+|   +------+         +------+|
      |   |Queue |-------->|Worker|+-+   |           |   ++-->|Queue |-------->|Worker||
      |   +------+         +------+|     +-----------+    |   +------+         +------+|
      +----------------------------+                      +----------------------------+

A spike node acts as a man-in-the-middle between two Buffy nodes, effectively
intercepting packets, messing with them, and then passing them along.  

Command line parameters:

```input_addr output_addr action_type [--seed seed --prob probability]```

You can start a spike node as follows:

```./spike 127.0.0.1:4500 127.0.0.1:5000 garble --seed 23423 --prob 20```

A seed can be provided for determinism, but keep in mind that 
nothing currently accounts for parallel processing across nodes and actors, 
so it's a pretty weak sense of "deterministic".

A probability of a spike event can also be provided. This is a number from
0 to 100 corresponding to a 0% to 100% chance that spike will act on any 
given packet.
