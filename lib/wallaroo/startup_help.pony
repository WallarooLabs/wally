/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

primitive StartupHelp
  fun apply(env: Env) =>
    @printf[I32](
      """
      To run Wallaroo:
      -----------------------------------------------------------------------------------
      --in/-i *[Comma-separated list of input addresses sources listen on]
      --control/-c *[Sets address for initializer control channel; sets
        control address to connect to for non-initializers]
      --data/-d *[Sets address for initializer data channel]
      --my-control [Optionally sets address for my control channel]
      --my-data [Optionally sets address for my data channel]
      --phone-home/-p [Sets address for phone home connection]
      --external/-e [Sets address for external message channel]
      --worker-count/-w *[Sets cluster initializer's total number of workers,
        including cluster initializer itself]
      --name/-n *[Sets name for this worker]

      --metrics/-m [Sets address for external metrics (e.g. monitoring hub)]
      --cluster-initializer/-t [Sets this process as the cluster
        initializing process (that status is meaningless after init is done)]
      --resilience-dir/-r [Sets directory to write resilience files to,
        e.g. -r /tmp/data (no trailing slash)]
      --event_log-file-length/-l [Optionally sets initial file length for event_log
        backend file]

      --join/-j [When a new worker is joining a running cluster, pass the
        control channel address of any worker as the value for this parameter]
      --stop-world/-u [Sets pause before state migration after stop the world]
      -----------------------------------------------------------------------------------
      """.cstring()
    )
