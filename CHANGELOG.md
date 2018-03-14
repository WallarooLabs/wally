# Change Log

All notable changes to Wallaroo will be documented in this file.

## [0.4.1] - 2018-01-12

- Go API: Fixed bug in state computation that return multiple results

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
