# Change Log

All notable changes to Wallaroo will be documented in this file.

## [unreleased] - unreleased

### Fixed

- Fix bug that caused Wallaroo to shut down when connecting a new source after a 3->2 shrink ([PR #2072](https://github.com/wallaroolabs/wallaroo/pull/2072))
- Correctly remove boundary references when worker leaves ([PR #2073](https://github.com/wallaroolabs/wallaroo/pull/2073))
- Correctly update routers after shrink ([PR #2018](https://github.com/wallaroolabs/wallaroo/pull/2018))
- Only try to shrink if supplied worker names are still in the cluster ([PR #2034](https://github.com/wallaroolabs/wallaroo/pull/2034))
- Fix bug when using cluster_shrinker with non-initializer ([PR #2011](https://github.com/wallaroolabs/wallaroo/pull/2011))
- Ensure that all running workers migrate to joiners ([PR #2027](https://github.com/wallaroolabs/wallaroo/pull/2027))
- Clean up recovery files during shrink ([PR #2012](https://github.com/wallaroolabs/wallaroo/pull/2012))
- Ensure that new sources don't try to connect to old workers ([PR #2004](https://github.com/wallaroolabs/wallaroo/pull/2004))
- Fail when control channel can't listen ([PR #1982](https://github.com/wallaroolabs/wallaroo/pull/1982))
- Only create output file for Giles sender when writing ([PR #1964](https://github.com/wallaroolabs/wallaroo/pull/1964))

### Added

- Inform joining worker to shut down on join error ([PR #2086](https://github.com/wallaroolabs/wallaroo/pull/2086))
- Add partition count observability query ([PR #2081](https://github.com/wallaroolabs/wallaroo/pull/2081))
- Add support for multiple sinks per pipeline ([PR #2060](https://github.com/wallaroolabs/wallaroo/pull/2060))
-  Allow joined worker to recover with original command line ([PR #1933](https://github.com/wallaroolabs/wallaroo/pull/1933))
- Add support for query requesting information about partition step distribution across workers ([PR #2025](https://github.com/wallaroolabs/wallaroo/pull/2025))
- Add tool to allow an operator to shrink a Wallaroo cluster ([PR #2005](https://github.com/wallaroolabs/wallaroo/pull/2005))

### Changed

- Clean up external message protocol ([PR #2032](https://github.com/wallaroolabs/wallaroo/pull/2032))
- Remove "name()" from StateBuilder interface ([PR #1988](https://github.com/wallaroolabs/wallaroo/pull/1988))

## [0.4.0] - 2018-01-12

### Fixed

- Do not force shrink count to a minimum of 1 ([PR #1931](https://github.com/wallaroolabs/wallaroo/pull/1931))
- Fix bug that caused worker joins to fail after the first successful round. ([PR #1927](https://github.com/wallaroolabs/wallaroo/pull/1927))

### Added

- Add "Running Wallaroo" section to book ([PR #1914](https://github.com/wallaroolabs/wallaroo/pull/1914))

### Changed

- New version of Python API based on decorators ([PR #1833](https://github.com/wallaroolabs/wallaroo/pull/1833))

## [0.3.3] - 2018-01-09

### Fixed

- Fix shrink autoscale query reply ([PR #1862](https://github.com/wallaroolabs/wallaroo/pull/1862))

### Added

- Initial Go API ([PR #1866](https://github.com/wallaroolabs/wallaroo/pull/1866))

### Changed

- Turn off building with AVX512f CPU extensions to work around a LLVM bug ([PR #1932](https://github.com/WallarooLabs/wallaroo/pull/1932))

## [0.3.2] - 2017-12-28

### Fixed

- Updates to documentation

## [0.3.1] - 2017-12-22

### Fixed

- Updates to documentation

## [0.3.0] - 2017-12-18

### Fixed

- Get ctrl-c to shutdown cluster after autoscale ([PR #1760](https://github.com/wallaroolabs/wallaroo/pull/1760))
- Send all unacked messages when resuming normal sending at OutgoingBoundary ([PR #1766](https://github.com/wallaroolabs/wallaroo/pull/1766))
- Fix bug in Python word count partitioning logic ([PR #1723](https://github.com/wallaroolabs/wallaroo/pull/1723))
- Add support for chaining State Partition -> Stateless Partition ([PR #1670](https://github.com/wallaroolabs/wallaroo/pull/1670))
- Fix Sender to properly dispose of files ([PR #1673](https://github.com/wallaroolabs/wallaroo/pull/1673))
- Create ProxyRouters to all required steps during initialization

### Added

- Add join for more than 1 worker simultaneously ([PR #1759](https://github.com/wallaroolabs/wallaroo/pull/1759))
- Add stateless partition shrink recalculation ([PR #1767](https://github.com/wallaroolabs/wallaroo/pull/1767))
- Add full support for partition routing to newly joined worker ([PR #1730](https://github.com/wallaroolabs/wallaroo/pull/1730))
- Shutdown cluster cleanly when SIGTERM or SIGINT is received ([PR #1705](https://github.com/wallaroolabs/wallaroo/pull/1705))

### Changed

- Don't report a cluster as ready to work until node connection protocol has completed ([PR #1771](https://github.com/wallaroolabs/wallaroo/pull/1771))
- Add Env as argument to source/sink builders ([PR #1734](https://github.com/wallaroolabs/wallaroo/pull/1734))
