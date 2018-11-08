<p align="center"><a href="https://www.wallaroolabs.com/"><img src="wallaroo-logo.png" alt="WallarooLabs logo" width="400"/></a></p>
<h2 align="center">Build and scale real-time applications as easily as writing a script</h2>

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

### What makes Wallaroo unique

Wallaroo is a little different than most stream processing tools. While most require the JVM, Wallaroo can be deployed as a separate binary. This means no more jar files. Wallaroo also isn't locked to just using [Kafka](kafka-link) as a source, use any source you like. Application logic can be written in Python 2, Python 3, or Pony.

## Getting Started

Wallaroo can either be installed via [Docker, Vagrant][docker-link] or (on Linux) via our handy [Wallaroo Up command][wally-up].

As easy as:

```sh
docker pull wallaroo-labs-docker-wallaroolabs.bintray.io/release/wallaroo:latest
```

Check out our [installation options][installation-options] page to learn more.

## Usage

Once you've installed Wallaroo, Take a look at some of our examples. A great place to start are our [word_count][word_count] or [market spread][market-spread] examples in [Python](python-examples).

```python
"""
This is a complete example application that receives lines of text and counts each word.
"""
import string
import struct
import wallaroo

def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    lines = wallaroo.source("Split and Count",
                        wallaroo.TCPSourceConfig(in_host, in_port, decoder))
    pipeline = (lines
        .to(split)
        .key_by(extract_word)
        .to(count_word)
        .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder)))

    return wallaroo.build_application("Word Count Application", pipeline)

@wallaroo.computation_multi(name="split into words")
def split(data):
    punctuation = " !\"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~"

    words = []

    for line in data.split("\n"):
        clean_line = line.lower().strip(punctuation)
        for word in clean_line.split(" "):
            clean_word = word.strip(punctuation)
            words.append(clean_word)

    return words

class WordTotal(object):
    count = 0

@wallaroo.state_computation(name="count word", state=WordTotal)
def count_word(word, word_total):
    word_total.count = word_total.count + 1
    return WordCount(word, word_total.count)

class WordCount(object):
    def __init__(self, word, count):
        self.word = word
        self.count = count

@wallaroo.key_extractor
def extract_word(data):
    return data

@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    return bs.decode("utf-8")

@wallaroo.encoder
def encoder(data):
    output = data.word + " => " + str(data.count) + "\n"
    print output
    return output.encode("utf-8")
```

## Documentation

Are you the sort who just wants to get going? Dive right into our [documentation][documentation] then! It will get you up and running with Wallaroo.

More information is also on our [blog][blog-link]. There you can find more insight into what we are working on and industry use-cases.

> Wallaroo currently exists as a mono-repo. All the source that is Wallaroo is located in this repo. See [application structure][application-structure-link] for more information.

## Need Help?

Trying to figure out how to get started?

 - Check out the [FAQ][faq]

 - Drop us a line:
    - [IRC][irc-link]
    - [Mailing List][group-link]
    - [Commercial Support][commercial-support-email]

## Contributing

We welcome contributions. Please see our [Contribution Guide][contribution-guide]

> For your pull request to be accepted you will need to accept our [Contributor License Agreement][cla]

## License

Wallaroo is licensed under the [Apache version 2][apache-2-license] license.

[apache-2-license]: https://www.apache.org/licenses/LICENSE-2.0
[application-structure-link]: MONOREPO.md
[blog-link]: https://blog.wallaroolabs.com/
[cla]: https://gist.github.com/WallarooLabsTeam/e06d4fed709e0e7035fdaa7249bf88fb
[commercial-support-email]: mailto:sales@wallaroolabs.com
[contribution-guide]: CONTRIBUTING.md
[docker-link]: https://docs.wallaroolabs.com/book/getting-started/choosing-an-installation-option.html
[documentation]: https://docs.wallaroolabs.com/
[go-examples]: examples/go/
[group-badge]: https://img.shields.io/badge/mailing%20list-join%20%E2%86%92-%23551A8B.svg
[group-link]: https://groups.io/g/wallaroo
[hello-wallaroo-post]: https://blog.wallaroolabs.com/2017/03/hello-wallaroo/
[home-page]: https://www.wallaroolabs.com/
[installation-options]: https://docs.wallaroolabs.com/book/getting-started/choosing-an-installation-option.html
[irc-badge]: https://img.shields.io/badge/IRC-join%20chat%20%E2%86%92-blue.svg
[irc-link]: https://webchat.freenode.net/?channels=#wallaroo
[kafka-link]: https://kafka.apache.org/
[word_count]: examples/python/word_count/
[market-spread]: examples/python/market_spread/
[overview-video]: https://vimeo.com/234753585
[python-examples]: examples/python/
[reverse]: examples/python/reverse/
[source-install-instructions]: https://docs.wallaroolabs.com/book/getting-started/linux-setup.html
[survey-link]: https://wallaroolabs.typeform.com/to/HS6azY?source=wallaroo_readme
[wallaroo-license-readme]: #license
[wally-up]: https://docs.wallaroolabs.com/book/getting-started/wallaroo-up.html
[faq]: https://www.wallaroolabs.com/faq
