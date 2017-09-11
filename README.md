# Wallaroo

Wallaroo is a fast, scalable data processing engine that rapidly takes you from prototype to production by eliminating infrastructure complexity.

- [What is Wallaroo?](#what-is-wallaroo)
- [Status](#status)
- [Quickstart](#quickstart)
- [Documentation](#documentation)
- [Getting Help](#getting-help)
- [How to Contribute](#how-to-contribute)
- [Additional Links](#additional-links)
- [About this Repo](#about-this-repo)

## What is Wallaroo?

Wallaroo is a framework for writing event-by-event distributed data processing applications. We’ve designed it to handle demanding high-throughput, low-latency tasks where accuracy of results is key. You can learn more about Wallaroo from our ["Hello Wallaroo!" blog post](https://blog.wallaroolabs.com/2017/03/hello-wallaroo/).

## Status

languages we are going to support, features. 
point to roadmap for more details.

what languages are currently supported. 
point to status of different features.

testing. 
billions of messages processed. 
we look forward to working with you to help solve your problems.
contact information.

## Quickstart

Are you the sort who just wants to get going? Dive right into our [documentation](http://docs.wallaroolabs.com) then! It will get you up and running with Wallaroo.

## Documentation

"community section of website"
[http://docs.wallaroolabs.com](http://docs.wallaroolabs.com)

## Getting Help

- [Join us on Freenode in #wallaroo](https://webchat.oftc.net/?channels=wallaroo). 
- [Join our mailing list](https://groups.io/g/wallaroo).

## How to Contribute

We're an open source project and welcome contributions. Trying to figure out how to get started? Drop us a line on [IRC](https://webchat.oftc.net/?channels=wallaroo) or the [mailing list](https://groups.io/g/wallaroo) and we can get you started.

Be sure to check out our [contributors guide](CONTRIBUTING.md) before you get started.

## Additional Links

## About this Repo

Wallaroo currently exists as a monorepo. All the source that makes Wallaroo go is in this repo. Let's take a quick walk through what you'll find in each top-level directory:

- atkin

Source for runner application that powers our still prototype Python "Actor" API.

- book

Markdown source used to build [http://docs.wallaroolabs.com](http://docs.wallaroolabs.com). [http://docs.wallaroolabs.com](http://docs.wallaroolabs.com) gets built from the latest commit to the `release` branch. There's also ["Wallaroo-Latest" documentation](https://www.gitbook.com/book/wallaroo-labs/wallaroo-latest/details). "Wallaroo-Latest" is built from master so it will be as up to date as possible. Be aware many of the external links in our documentation point to the `release` branch. "Wallaroo-Latest" is intended only for the most adventurous amongst us.

- cpp_api

Code for writing Wallaroo applications using C++. This is currently unsupported.

- examples

Wallaroo example applications in a variety of langugages. Currently only the Python API examples are supported.

- giles

TCP utlity applications that can stream data over TCP to Wallaroo applications and receive TCP streams from said applications. 

- lib

The Pony source code that makes up Wallaroo.

- machida

Python runner application. Machida embeds a Python interpreter inside a native Wallaroo binary and allows you to run applications using the Wallaroo Python API.

- monitoring hub

Source for the Wallaroo metrics UI.

- orchestration

Tools we use to spin up machines in AWS and other environments.

- testing

Tools we have written that are used to test Wallaroo.

- utils

End user utilities designed to make it easier to do various Wallaroo tasks like cleanly shut down a cluster.
