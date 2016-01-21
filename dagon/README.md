# dagon

Alter reality... by setting up a topology. Then test it.

## Usage

You'll need to install the click package.

```
python3.5 -m pip install click
```

At the moment, you need to manually compile spike and giles in their
respective folders before running dagon.

Run a dagon test as follows:

```python3.5 dagon.py topology-name duration [--seed seed]```

```topology-name``` corresponds to the name of the topology config file.
For example, if your topology is called "topos", then you should name
your config file ```topos.ini```.

```duration``` sets the duration of the test.

```--seed``` is an optional parameter that seeds random number generators within spike.

## Topology Configuration

You configure the topology in a config file with the extension ```.ini```.
It consists of two section types. ```[edges]```
is the section where edges are defined. Any other section name is interpreted
as the name of a node.

In the ```[edges]``` section, the order in which you specify edges matters. The origin of the first edge
is the source of the topology. The target of the last edge is the sink of
the topology. Giles outputs to the source and reads from the sink.  

Edges are specified as follows:  
* ```node-1:node-2```: creates an edge from node-1 to node-2
* ```node-2:node-3,node-4```: creates an edge from node-2 to node-3 and an edge from node-2 to node-4

Note that multi-output nodes are not currently supported.

An individual node can be configured with the following fields:  
* ```d```: destructive action performed by corresponding spike node
* ```p```: probability that the action will be taken for any given packet

Example:

```
[node-1]
d = duplicate
p = 25

[node-2]
d = drop
p = 10

[node-3]
d = reorder
p = 25

[node-4]

[node-5]
d = pass

[edges]
node-1:node-2
node-2:node-3
node-3:node-4
node-4:node-5
```
