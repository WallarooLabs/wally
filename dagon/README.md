# dagon

Alter reality... by setting up a topology. Then test it.

## Usage

Dagon sets up and runs a topology of buffy, spike, and giles nodes
based on an .ini file you provide. It automatically assigns ports
and checks that your topology has a single source and a single sink.

You'll need to install the click and numpy packages.

```
python3 -m pip install click
python3 -m pip install numpy
```

At the moment, you need to manually compile spike and giles in their
respective folders before running dagon.

Run a dagon test as follows:

```python3 dagon.py topology-name [--duration duration --seed seed --test test-function --dotgen]```

```topology-name``` corresponds to the name of the topology config file.
For example, if your topology is called "topos", then you should name
your config file ```topos.ini```.

```--messages``` is an optional parameter that sets the number of messages to
send. The default is 100.

```--ttf``` is an optional parameter that sets the how many seconds  Giles
should wait for the first message to arrive before giving up and shutting down.
The default is 60.

```--tsl``` is an optional parameter that sets the how many seconds Giles
should wait since the last messaged arrive before giving up and shutting down.
The default is 60.

```--seed``` is an optional parameter that seeds random number generators within spike.

```--test``` is an optional parameter for specifying the test function for checking inputs
against outputs. This function must be defined in a python source file in the ```config``` folder,
as a function with the name and signature ```func(input, output)``` and returning a boolean.
A function checking for identity is the default.

```--mismatch``` is an option parameter specifying that we expect there to be mismatched output
as part of the results.

```--metrics``` is a flag that causes dagon to display metrics (throughput/latency)

```--dotgen``` is a flag that causes dagon to output a graphviz dot file of the topology.
This flag also skips running any tests.

```--docker``` is a flag that causes dagon to use docker to run processes. It defaults to `false`.

```--docker_host``` is an optional parameter that tells dagon which docker daemon to connect to. It defaults to `unix:///var/run/docker.sock`.

```--docker_tag``` is an optional parameter that tells dagon which tag to use when pulling/running docker containers. It defaults to the output of `git describe --tags --always`.

Dagon ships with a working example topology name `dagon`, to run it, you should run:

`python3 dagon.py dagon`

### Docker examples

The following two examples are for running dagon using docker images that have already been built and pushed to the Sendence private repository. These have been tested/confirmed to work on both x86_64 (Vagrant/AWS) and armhf (hypriot).

The following example runs dagon to start processes in docker on the local docker daemon:

`./dagon.py --docker --docker_tag 0.0.3-sendence-88-g3c592b0 --test double --duration 3 dagon`

The following example runs dagon to start processes in docker on a remote docker daemon (on docker swarm if running on nodes using orchestration in this repo):

`./dagon.py --docker --docker_tag 0.0.3-sendence-88-g3c592b0 --docker_host <BUFFY-LEADER-IP>:2378 --test double --duration 3 dagon`

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
* ```f```: function/computation performed at node
* ```d```: destructive action performed by corresponding spike node
* ```p```: probability that the action will be taken for any given packet

Example:

```
[node-1]
f = double
d = duplicate
p = 25

[node-2]
f = passthrough
d = drop
p = 10

[node-3]
f = passthrough
d = reorder
p = 25

[node-4]
f = passthrough

[node-5]
f = passthrough
d = pass

[edges]
node-1:node-2
node-2:node-3
node-3:node-4
node-4:node-5
```

## Generating Image of Topology

Dagon can export the topology configured in the .ini file as a graphviz .dot file.
You can use this .dot file to generate an image of the topology.
 
If you have not installed it, you will need graphviz. On OSX, run

```brew install graphviz```

To generate a .dot file for a topology named ```test```, run

```python3 dagon.py test --dotgen```

This will create (or overwrite) a file called ```test.dot```. Once this file
exists, you can run

```dot -Tpng test.dot -o test.png```

This will output an image called test.png.
