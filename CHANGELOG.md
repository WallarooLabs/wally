# Changelog

All notable changes to Wallaroo will be documented in this file.

## [unreleased] - unreleased

### Fixed

- Send all unacked messages when resuming normal sending at OutgoingBoundary ([PR #1766](https://github.com/wallaroolabs/wallaroo/pull/1766))
- Fix bug in Python word count partitioning logic ([PR #1723](https://github.com/wallaroolabs/wallaroo/pull/1723))
- Add support for chaining State Partition -> Stateless Partition ([PR #1670](https://github.com/wallaroolabs/wallaroo/pull/1670))
- Fix Sender to properly dispose of files ([PR #1673](https://github.com/wallaroolabs/wallaroo/pull/1673))
- Create ProxyRouters to all required steps during initialization

### Added

- Add full support for partition routing to newly joined worker ([PR #1730](https://github.com/wallaroolabs/wallaroo/pull/1730))
- Shutdown cluster cleanly when SIGTERM or SIGINT is received ([PR #1705](https://github.com/wallaroolabs/wallaroo/pull/1705))
### Changed

- Add Env as argument to source/sink builders ([PR #1734](https://github.com/wallaroolabs/wallaroo/pull/1734))
- Changelog Hook Test 2 ([PR #1669](https://github.com/wallaroolabs/wallaroo/pull/1669))
