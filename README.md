<p align="center"><a href="https://www.wallaroolabs.com/"><img src="wallaroo-logo.png" alt="WallarooLabs logo" width="400"/></a></p>
<h2 align="center">Build and scale real-time applications as easily as writing a script</h2>

---
[![CircleCI](https://circleci.com/gh/WallarooLabs/wallaroo.svg?style=shield)](https://circleci.com/gh/WallarooLabs/wallaroo)
[![GitHub license](https://img.shields.io/badge/license-apache%202-blue.svg)][wallaroo-community-license-readme]
[![GitHub version](https://badge.fury.io/gh/WallarooLabs%2Fwallaroo.svg)](http://badge.fury.io/gh/WallarooLabs%2Fwallaroo)
[![IRC][irc-badge]][irc-link]
[![Groups.io][group-badge]][group-link]

Wallaroo is a fast, stream processing framework that rapidly takes you from prototype to production by eliminating infrastructure complexity. Infinitely scalable and backed by a highly durable key-value store.

## What is Wallaroo?

When we set out to build Wallaroo, we had several high-level goals in mind:

- Create a dependable and resilient distributed computing framework
- Take care of the complexities of distributed computing "plumbing," allowing developers to focus on their business logic
- Provide high-performance & low-latency data processing
- Language agnostic
- Be portable (i.e., run on-prem or any cloud)
- Manage in-memory state for the application
- Allow applications to scale as needed, even when they are live and up-and-running

You can learn more about [Wallaroo][home-page] from our ["Hello Wallaroo!" blog post][hello-wallaroo-post] and the [Wallaroo overview video][overview-video].

### What makes Wallaroo unique

Wallaroo is a little different than most stream processing tools. While most require the JVM, Wallaroo can be deployed as a separate binary. This means no more jar files. Wallaroo also isn't locked to just using [Kafka](kafka-link) as a source, use any source you like.

## Getting Started

Wallaroo can either be installed via [Docker, Vagrant][docker-link] or (on Linux) complied from [source][source-install-instructions].

As easy as:

```sh
docker pull wallaroo-labs-docker-wallaroolabs.bintray.io/release/wallaroo:0.5.1
```

## Usage

Once you've installed Wallaroo, Take a look at some of our examples [reverse][reverse] or [market spread][market-spread] examples in either [Python](python-examples) or [Go](go-examples).

```python
"""
This is an example application that receives strings as input and outputs the
reversed strings.
"""

def application_setup(args):
  # see ./examples/python/reverse

@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    return bs.decode("utf-8")

@wallaroo.computation(name="reverse")
def reverse(data):
    return data[::-1]

@wallaroo.encoder
def encoder(data):
    # data is a string
    return data + "\n"
```

## Documentation

Are you the sort who just wants to get going? Dive right into our [documentation][documentation] then! It will get you up and running with Wallaroo.

More information is also on our [blog][blog-link]. There you can find more insight into what we are working on and industry use-cases.

> Wallaroo currently exists as a mono-repo. All the source that is Wallaroo is located in this repo

## Need Help?

Trying to figure out how to get started? Drop us a line on:

- [IRC][irc-link]
- [Mailing List][group-link]
- [Commercial Support][contact-us-email]

## Contributing

We welcome contributions. Please see our [Contribution Guide][contribution-guide]

> For your pull request to be accepted you will need to accept our [Contributor License Agreement][cla]

## License

The [Wallaroo Community License][wallaroo-community-license] is based on [Apache version 2][apache-2-license]. However, you should read it for yourself. Here we provide a summary of the main points of the [Wallaroo Community License Agreement][wallaroo-community-license].

- You can **run** all Wallaroo code in a non-production environment without restriction.
- You can **run** all Wallaroo code in a production environment for free on up to 3 server or 24 cpus.
- If you want to **run** Wallaroo Enterprise version features in production above 3 servers or 24 cpus, you have to obtain a license.
- You can **modify** and **redistribute** any Wallaroo code
- Anyone who uses your **modified** or **redistributed** code is bound by the same license and needs to obtain a Wallaroo Enterprise license to run on more than 3 servers or 24 cpus in a production environment.

[apache-2-license]: https://www.apache.org/licenses/LICENSE-2.0
[blog-link]: https://blog.wallaroolabs.com/
[cla]: https://gist.github.com/WallarooLabsTeam/e06d4fed709e0e7035fdaa7249bf88fb
[contact-us-email]: mailto:hello@wallaroolabs.com
[contribution-guide]: CONTRIBUTING.md
[docker-link]: https://docs.wallaroolabs.com/book/getting-started/choosing-an-installation-option.html
[documentation]: https://docs.wallaroolabs.com/
[group-badge]: https://img.shields.io/badge/mailing%20list-join%20%E2%86%92-%23551A8B.svg
[group-link]: https://groups.io/g/wallaroo
[hello-wallaroo-post]: https://blog.wallaroolabs.com/2017/03/hello-wallaroo/
[home-page]: https://www.wallaroolabs.com/
[irc-badge]: https://img.shields.io/badge/IRC-join%20chat%20%E2%86%92-blue.svg
[irc-link]: https://webchat.freenode.net/?channels=#wallaroo
[market-spread]: examples/python/market_spread/
[overview-video]: https://vimeo.com/234753585
[reverse]: examples/python/reverse/
[source-install-instructions]: https://docs.wallaroolabs.com/book/getting-started/linux-setup.html
[wallaroo-community-license-readme]: #license
[wallaroo-community-license]: LICENSE.md
