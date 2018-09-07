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
  fun apply() =>
    @printf[I32](
      """

      -------------------------------------------------------------------------
      Wallaroo takes the following parameters:
      -------------------------------------------------------------------------
        --control/-c [Sets address for initializer control channel; sets
          control address to connect to for non-initializers]
        --data/-d [Sets address for initializer data channel]
        --my-control [Optionally sets address for my control channel]
        --my-data [Optionally sets address for my data channel]
        --external/-e [Sets address for external message channel]
        --worker-count/-w [Sets cluster initializer's total number of workers,
          including cluster initializer itself]
        --name/-n [Sets name for this worker]

        --metrics/-m [Sets address for external metrics (e.g. monitoring hub)]
        --cluster-initializer/-t [Sets this process as the cluster
          initializing process (that status is meaningless after init is done)]
        --resilience-dir/-r [Sets directory to write resilience files to,
          e.g. -r /tmp/data (no trailing slash)]
        --resilience-no-local-file-io [Disables local file I/O; writes to I/O
          journal are not affected by this flag]
        --resilience-disable-io-journal [Disables the write-ahead logging
          of all file I/O (regardless of resilience build type)]
        --log-rotation [Enables log rotation. Default: off]
        --event-log-file-size/-l [Optionally sets rotation size for the event
          log file backend]

        --join/-j [When a new worker is joining a running cluster, pass the
          control channel address of any worker as the value for this
          parameter]
        --stop-world/-u [Sets pause before state migration after stop the
          world]

      -------------------------------------------------------------------------
      To set Wallaroo modes, compile with the following -D flags:
        resilience - Sets resilience mode
        autoscale - Sets autoscaling mode
        clustering - Sets clustering mode
      -------------------------------------------------------------------------
      NOTE: There may be app-specific command line options that are not listed
        here
      -------------------------------------------------------------------------
      """.cstring()
    )
