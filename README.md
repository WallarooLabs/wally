# Wallaroo

Wallaroo is a fast, scalable data processing engine that rapidly takes you from prototype to production by eliminating infrastructure complexity.

- [What is Wallaroo?][what is wallaroo section]
- [Status][status section]
- [Getting Started][getting started section]
- [Documentation][documentation section]
- [Getting Help][getting help section]
- [How to Contribute][contribute section]
- [Additional Links][additional links]
- [About this Repository][about this repository section]

## What is Wallaroo?

Wallaroo is a framework for writing event-by-event distributed data processing applications. We’ve designed it to handle demanding high-throughput, low-latency tasks where the accuracy of results is essential. Wallaroo takes care of mechanics of scaling, resilience, state management, and message delivery. We've designed Wallaroo to make it easy scale applications with no code changes, and allow programmers to focus on business logic. You can learn more about Wallaroo from our ["Hello Wallaroo!" blog post][hello wallaroo post].

### Features

- State Management
- Scale running stateful applications with zero downtime
- Resilience in the face of failures
- Exactly-once message processing

### Language Bindings

Existing language bindings: 

- Python 2.7
- C++
- Pony

Planned Language bindings:

- Python 3
- Go
- JavaScript

Please see [status][status section] for language binding support details. Wallaroo is open source software with an expanding software community. Please see the [How to Contribute][contribute section] section if you wish to help support your favorite data analysis language.

### Supported platforms

- Linux
- MacOS

Wallaroo is open source software with an expanding software community. Please see the [How to Contribute][contribute section] section if you wish to help support your favorite operating system.

### Deployment model

Wallaroo applications are user hosted. It's equally at home "in the cloud" or "on premises."

We have no "as a service" offering at this time. 

## Status

### Language bindings

- Pony

Wallaroo is primarily written in Pony. As such, Pony is the first language to receive support for any given feature. We don't expect the Pony API to get much usage outside of Wallaroo Labs. We aren't maintaining any documentation for the Pony API outside of a [few examples][pony examples]. You are welcome to use the Pony API but are going to mostly be on your own documentation wise.

- Python 2.7

Currently, Python 2.7 is our primary focus. As we add features to the Wallaroo, we will be adding corresponding Python APIs and documentation.

- Python 3

We are planning on adding Python 3 support when there is enough demand. If you are interested in writing Wallaroo applications using Python 3, please get in touch.

- C++

C++ was our first non-Pony API. Since that time we have learned a lot about writing Wallaroo language bindings. We plan on revisiting the C++ API in the future to improve its ergonomics. New functionality added to Wallaroo is not currently being implemented in the C++ API. If you are interested in using Wallaroo with C++, you should contact us. We're happy to work with you.

- Go

We are currently working with a client who is very interested in writing Wallaroo applications in Go. We plan to introduce Go language bindings by the end of 2017. 

- JavaScript 

JavaScript support is currently in the planning stages with no release date targeted. 

### Limitations

We have [numerous issues open][open issues] to improve existing Wallaroo functionality. For a high-level overview, please see our [current limitations document][current limitations].

## Getting Started

Are you the sort who just wants to get going? Dive right into our [documentation][documentation website] then! It will get you up and running with Wallaroo.

## Documentation

Our primary documentation is hosted by GitBook at [http://docs.wallaroolabs.com][documentation website]. You can find additional information on our [community site][community website].

## Getting Help

- [Join us on Freenode in #wallaroo][IRC]. 
- [Join our developer mailing list][developer mailing list].
- [Commercial support][contact us email]

## How to Contribute

We're an open source project and welcome contributions. Trying to figure out how to get started? Drop us a line on [IRC][IRC] or the [developer mailing list][developer mailing list], and we can get you started.

Be sure to check out our [contributors guide][contributors guide] before you get started.

## Additional Links

- [Hello Wallaroo!][hello wallaroo post]

An introduction to Wallaroo.

- [What's the "Secret Sauce"][secret sauce post]

A look inside Wallaroo's excellent performance

- [Wallaroo Labs][wallaroo labs website]

The company behind Wallaroo.

- [Documentation][documentation website]

Wallaroo documentation.

- QCon NY 2016: [How did I get here? Building Confidence in a Distributed Stream Processor][qcon16 how did i get here]
- CodeMesh 2016:[How did I get here? Building Confidence in a Distributed Stream Processor][codemesh16 how did i get here]

Our VP of Engineering Sean T. Allen talks about one of the techniques we use to test Wallaroo.

- [Wallaroo Labs Twitter][twitter]

## About this Repository

Wallaroo currently exists as a mono-repo. All the source that makes Wallaroo go is in this repo. Let's take a quick walk through what you'll find in each top-level directory:

- book

Markdown source used to build [http://docs.wallaroolabs.com][documentation website]. [http://docs.wallaroolabs.com][documentation website] gets built from the latest commit to the `release` branch. There's also ["Wallaroo-Latest" documentation][unstable documentation website]. "Wallaroo-Latest" is built from master so it will be as up to date as possible. Be aware many of the external links in our documentation point to the `release` branch. "Wallaroo-Latest" is intended only for the most adventurous amongst us.

- cpp_api

Code for writing Wallaroo applications using C++. This is currently unsupported.

- examples

Wallaroo example applications in a variety of languages. Currently, only the Python API examples are supported. See [status section][status section] for details.

- giles

TCP utility applications that can stream data over TCP to Wallaroo applications and receive TCP streams from said applications. 

- lib

The Pony source code that makes up Wallaroo.

- machida

Python runner application. Machida embeds a Python interpreter inside a native Wallaroo binary and allows you to run applications using the Wallaroo Python API.

- monitoring hub

Source for the Wallaroo metrics UI.

- orchestration

Tools we use to create machines in AWS and other environments.

- testing

Tools we have written that are used to test Wallaroo.

- utils

End user utilities designed to make it easier to do various Wallaroo tasks like cleanly shut down a cluster.

[about this repository section]: #about-this-repository 
[additional links]: #additional-links
[codemesh16 how did i get here]: https://www.youtube.com/watch?v=6MsPDtpe2tg
[community website]: http://www.wallaroolabs.com/community
[contact us email]: mailto:hello@wallaroolabs.com
[contribute section]: #how-to-contribute
[contributors guide]: CONTRIBUTING.md
[current limitations]: LIMITATIONS.md
[developer mailing list]: https://groups.io/g/wallaroo
[documentation section]: #documentation
[documentation website]: http://docs.wallaroolabs.com
[getting help section]: #getting-help
[getting started section]: #getting-started
[hello wallaroo post]: https://blog.wallaroolabs.com/2017/03/hello-wallaroo/
[IRC]: https://webchat.oftc.net/?channels=wallaroo
[open issues]: https://github.com/WallarooLabs/wallaroo/issues
[pony examples]: examples/pony
[qcon16 how did i get here]: https://www.infoq.com/presentations/trust-distributed-systems
[secret sauce post]: https://blog.wallaroolabs.com/2017/06/whats-the-secret-sauce/
[status section]: #status
[twitter]: https://www.twitter.com/wallaroolabs
[unstable documentation website]: https://www.gitbook.com/book/wallaroo-labs/wallaroo-latest/details
[wallaroo labs website]: https://www.wallaroolabs.com
[what is wallaroo section]: #what-is-wallaroo
