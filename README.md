<p align="center"><a href="https://www.wallaroolabs.com/"><img src="wallaroo-logo.png" alt="WallarooLabs logo" width="400"/></a></p>
<h2 align="center">Build and scale real-time applications</h2>

---
[![CircleCI](https://circleci.com/gh/WallarooLabs/wallaroo.svg?style=shield)](https://circleci.com/gh/WallarooLabs/wallaroo)
[![GitHub license](https://img.shields.io/badge/license-apache%202-blue.svg)][wallaroo-license-readme]
[![GitHub version](https://badge.fury.io/gh/WallarooLabs%2Fwallaroo.svg)](http://badge.fury.io/gh/WallarooLabs%2Fwallaroo)
[![IRC][irc-badge]][irc-link]
[![Groups.io][group-badge]][group-link]

A fast, stream-processing framework. Wallaroo makes it easy to react to data in real-time. By eliminating infrastructure complexity, going from prototype to production has never been simpler.

## What is Wallaroo?

When we set out to build Wallaroo, we had several high-level goals in mind:

- Create a dependable and resilient distributed computing framework
- Take care of the complexities of distributed computing "plumbing," allowing developers to focus on their business logic
- Provide high-performance & low-latency data processing
- Be portable and deploy easily (i.e., run on-prem or any cloud)
- Manage in-memory state for the application
- Allow applications to scale as needed, even when they are live and up-and-running

You can learn more about [Wallaroo][home-page] from our ["Hello Wallaroo!" blog post][hello-wallaroo-post] and the [Wallaroo overview video][overview-video].

## Getting Started

Wallaroo can be installed via our handy Wallaroo Up command. Check out our [installation][installation-options] page to learn more.

## APIs

The primary API for Wallaroo is written in [Pony][pony]. If you are interested in writing Wallaroo applications in other high-performance languages such as C, C++ or Rust, [drop us a line][commercial-support-email]; we'd be happy to engage on a commercial basis in creating language bindings that meet your needs.

## Usage

Once you've installed Wallaroo, Take a look at some of our examples. A great place to start are our [word_count][word_count] or [market spread][market-spread] examples in [Pony](pony-examples).

```pony
"""
Word Count App
"""
use "assert"
use "buffered"
use "collections"
use "net"
use "serialise"
use "wallaroo_labs/bytes"
use "wallaroo"
use "wallaroo_labs/logging"
use "wallaroo_labs/mort"
use "wallaroo_labs/time"
use "wallaroo/core/common"
use "wallaroo/core/metrics"
use "wallaroo/core/sink/tcp_sink"
use "wallaroo/core/source"
use "wallaroo/core/source/tcp_source"
use "wallaroo/core/state"
use "wallaroo/core/topology"

actor Main
  new create(env: Env) =>
    Log.set_defaults()
    try
      let pipeline = recover val
        let lines = Wallaroo.source[String]("Word Count",
          TCPSourceConfig[String].from_options(StringFrameHandler,
                TCPSourceConfigCLIParser("Word Count", env.args)?, 1))

        lines
          .to[String](Split)
          .key_by(ExtractWord)
          .to[RunningTotal](AddCount)
          .to_sink(TCPSinkConfig[RunningTotal].from_options(
            RunningTotalEncoder, TCPSinkConfigCLIParser(env.args)?(0)?))
      end
      Wallaroo.build_application(env, "Word Count", pipeline)
    else
      @printf[I32]("Couldn't build topology\n".cstring())
    end

primitive Split is StatelessComputation[String, String]
  fun name(): String => "Split"

  fun apply(s: String): Array[String] val =>
    let punctuation = """ !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~ """
    let words = recover trn Array[String] end
    for line in s.split("\n").values() do
      let cleaned =
        recover val s.clone().>lower().>lstrip(punctuation)
          .>rstrip(punctuation) end
      for word in cleaned.split(punctuation).values() do
        words.push(word)
      end
    end
    consume words

class val RunningTotal
  let word: String
  let count: U64

  new val create(w: String, c: U64) =>
    word = w
    count = c

class WordTotal is State
  var count: U64

  new create(c: U64) =>
    count = c

primitive AddCount is StateComputation[String, RunningTotal, WordTotal]
  fun name(): String => "Add Count"

  fun apply(word: String, state: WordTotal): RunningTotal =>
    state.count = state.count + 1
    RunningTotal(word, state.count)

  fun initial_state(): WordTotal =>
    WordTotal(0)

primitive StringFrameHandler is FramedSourceHandler[String]
  fun header_length(): USize =>
    4

  fun payload_length(data: Array[U8] iso): USize ? =>
    Bytes.to_u32(data(0)?, data(1)?, data(2)?, data(3)?).usize()

  fun decode(data: Array[U8] val): String =>
    String.from_array(data)

primitive ExtractWord
  fun apply(input: String): Key =>
    input

primitive RunningTotalEncoder
  fun apply(t: RunningTotal, wb: Writer = Writer): Array[ByteSeq] val =>
    let result =
      recover val
        String().>append(t.word).>append(", ").>append(t.count.string())
          .>append("\n")
      end
    @printf[I32]("!!%s".cstring(), result.cstring())
    wb.write(result)

    wb.done()
```

## Documentation

Are you the sort who just wants to get going? Dive right into our [documentation][documentation] then! It will get you up and running with Wallaroo.

More information is also on our [blog][blog-link]. There you can find more insight into what we are working on and industry use-cases.

> Wallaroo currently exists as a mono-repo. All the source that is Wallaroo is located in this repo. See [repo directory structure][repo-directory-structure-link] for more information.

You can also take a look at our [FAQ][faq].

## Need Help?

Trying to figure out how to get started? Drop us a line:

- [Mailing List][group-link]
- [Commercial Support][commercial-support-email]

## Contributing

We welcome contributions. Please see our [Contribution Guide][contribution-guide]

> For your pull request to be accepted you will need to accept our [Contributor License Agreement][cla]

## License

Wallaroo is licensed under the [Apache version 2][apache-2-license] license.

[apache-2-license]: https://www.apache.org/licenses/LICENSE-2.0
[repo-directory-structure-link]: MONOREPO.md
[blog-link]: https://blog.wallaroolabs.com/
[cla]: https://gist.github.com/WallarooLabsTeam/e06d4fed709e0e7035fdaa7249bf88fb
[commercial-support-email]: mailto:sales@wallaroolabs.com
[contribution-guide]: CONTRIBUTING.md
[documentation]: https://docs.wallaroolabs.com/
[faq]: https://wallaroolabs.com/faq
[group-badge]: https://img.shields.io/badge/mailing%20list-join%20%E2%86%92-%23551A8B.svg
[group-link]: https://groups.io/g/wallaroo
[hello-wallaroo-post]: https://blog.wallaroolabs.com/2017/03/hello-wallaroo/
[home-page]: https://www.wallaroolabs.com/
[installation-options]: https://docs.wallaroolabs.com/pony-installation
[word_count]: examples/pony/word_count/
[market-spread]: examples/pony/market_spread/
[pony]: https://www.ponylang.io/
[pony-examples]: examples/pony/
[wallaroo-license-readme]: #license
