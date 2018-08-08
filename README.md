![Wallaroo Logo](wallaroo-logo.png)
---

Wallaroo is a fast, elastic data processing engine that rapidly takes you from prototype to production by eliminating infrastructure complexity.

- [What is Wallaroo?][what is wallaroo section]
- [Status][status section]
- [Getting Started][getting started section]
- [Documentation][documentation section]
- [Getting Help][getting help section]
- [How to Contribute][contribute section]
- [License][license section]
- [Frequently Asked Questions][FAQ]
- [Additional Links][additional links]
- [About this Repository][about this repository section]

## What is Wallaroo?


Wallaroo is a fast and elastic data processing engine that rapidly takes you from prototype to production. 

When we set out to build Wallaroo, we had several high-level goals in mind:

- Create a dependable and resilient distributed computing framework
- Take care of the complexities of distributed computing "plumbing," allowing developers to focus on their business logic
- Provide high-performance & low-latency data processing
- Be portable (i.e., run on-prem or any cloud)
- Manage in-memory state for the application
- Allow applications to scale as needed, even when they are live and up-and-running

You can learn more about Wallaroo from our ["Hello Wallaroo!" blog post][hello wallaroo post].

We've done a [15-minute video of our engineering presentation][scale independence with wallaroo] that has helped people understand what Wallaroo is. If you watch it, you will get:

- An overview of the problem we are solving with our Scale-Independent API
- A short intro to the Python API
- A demonstration of our Autoscale functionality (for stateful applications)
- To see the power of Scale-Independent APIs in action

### Features

- [State Management][state management website]
- [Scale running stateful applications with zero downtime][autoscaling website]
- [Resilience in the face of failures][resilience website]
- [Exactly-once message processing][exactly-once website]

### Language Bindings

Existing language bindings: 

- Python 2.7
- C++
- Go
- Pony

Planned Language bindings:

- Python 3
- JavaScript

Please see [status][status section] for language binding support details. Wallaroo is open source software with an expanding software community. Please see the [How to Contribute][contribute section] section if you wish to help support your favorite data analysis language.

### Supported platforms

- Linux
- MacOS

Wallaroo is open source software with an expanding software community. Please see the [How to Contribute][contribute section] section if you wish to help support your favorite operating system.

### Deployment model

Wallaroo applications are user hosted. It's equally at home "in the cloud" or "on-premise."

We have no "as a service" offering at this time. 

### Roadmap

Interested in where we are taking Wallaroo? Check out our [roadmap][roadmap].

## Status

### Language bindings

- Pony

Wallaroo is primarily written in Pony. As such, Pony is the first language to receive support for any given feature. We don't expect the Pony API to get much usage outside of Wallaroo Labs. We aren't maintaining any documentation for the Pony API outside of a [few examples][pony examples]. You are welcome to use the Pony API but are going to mostly be on your own documentation wise.

- Python 2.7

Along with Go, Python 2.7 is our primary focus. As we add features to the Wallaroo, we will be adding corresponding Python APIs and documentation.

- Python 3

We are currently working with a client who needs Python 3 bindings. We plan to introduce Python 3 bindings in late 2018.

- C++

C++ is currently unsupported and apps created with the C++ API will not build unless you checkout the `last-working-C++-commit` tag. If you are interested in using Wallaroo with C++, you should [contact us][contact us email]. We're happy to work with you.

C++ was our first non-Pony API. Since that time we have learned a lot about writing Wallaroo language bindings. We plan on revisiting the C++ API in the future to improve its ergonomics. New functionality added to Wallaroo is not currently being implemented in the C++ API. 

- Go

Along with Python 2.7, Go is our primary focus. As we add features to the Wallaroo, we will be adding corresponding Go APIs and documentation. The currently available version of the Go API is our first pass. We're quite interested in getting your feedback and improving it.

- JavaScript 

JavaScript support is currently in the planning stages with a release in 2018.

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

## License

Wallaroo is an open source project. All of the source code is available to you. Most of the Wallaroo code base is available under the [Apache License, version 2][apache 2 license]. However, not all of the Wallaroo source code is [Apache 2][apache 2 license] licensed. Parts of Wallaroo are licensed under the [Wallaroo Community License Agreement][wallaroo community license]. Source files in this repository have a header indicating which license they are under. Currently, all files that are licensed under the [Wallaroo Community License Agreement][wallaroo community license] are in the `lib/wallaroo/ent` directory. 

The core stream processing engine and state management facilities are all licensed under the the [Apache version 2][apache 2 license]. Autoscaling, exactly-once message processing and resiliency features are licensed under the [Wallaroo Community License Agreement][wallaroo community license].

The [Wallaroo Community License][wallaroo community license] is based on [Apache version 2][apache 2 license]. However, you should read it for yourself. Here we provide a summary of the main points of the [Wallaroo Community License Agreement][wallaroo community license].

- You can **run** all Wallaroo code in a non-production environment without restriction.
- You can **run** all Wallaroo code in a production environment for free on up to 3 server or 24 cpus.
- If you want to **run** Wallaroo Enterprise version features in production above 3 servers or 24 cpus, you have to obtain a license.
- You can **modify** and **redistribute** any Wallaroo code
- Anyone who uses your **modified** or **redistributed** code is bound by the same license and needs to obtain a Wallaroo Enterprise license to run on more than 3 servers or 24 cpus in a production environment. 

Please [contact us][contact us email] if you have any questions about licensing or Wallaroo Enterprise.

## Additional Links

- [Scale-Independence with Wallaroo][scale independence with wallaroo]

15 minute overview of key Wallaroo features. Includes actual code and a demonstration of our stateful autoscaling functionality.

- [Open Sourcing Wallaroo][open sourcing wallaroo]

Our open source annoucement.

- [Hello Wallaroo!][hello wallaroo post]

An introduction to Wallaroo.

- [What's the "Secret Sauce"][secret sauce post]

A look inside Wallaroo's excellent performance

- [Wallaroo Labs][wallaroo labs website]

The company behind Wallaroo.

- [Documentation][documentation website]

Wallaroo documentation.

- [Wallaroo Labs' Blog][blog]

Wallaroo Labs blog.

- QCon NY 2016: [How did I get here? Building Confidence in a Distributed Stream Processor][qcon16 how did i get here]
- CodeMesh 2016:[How did I get here? Building Confidence in a Distributed Stream Processor][codemesh16 how did i get here]

Our VP of Engineering Sean T. Allen talks about one of the techniques we use to test Wallaroo.

- [Wallaroo Labs Twitter][twitter]

## About this Repository

Wallaroo currently exists as a mono-repo. All the source that makes Wallaroo go is in this repo. Let's take a quick walk through what you'll find in each top-level directory:

- book

Markdown source used to build [http://docs.wallaroolabs.com][documentation website]. [http://docs.wallaroolabs.com][documentation website] gets built from the latest commit to the `release` branch.

- cpp_api

Code for writing Wallaroo applications using C++. This is currently unsupported.

- examples

Wallaroo example applications in a variety of languages. Currently, only the Python API examples are supported. See [status section][status section] for details.

- giles

TCP utility applications that can stream data over TCP to Wallaroo applications and receive TCP streams from said applications. 

- go_api

Code for writing Wallaroo applications using Go.

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
[apache 2 license]: https://www.apache.org/licenses/LICENSE-2.0
[autoscaling website]: http://www.wallaroolabs.com/technology/autoscaling
[blog]: https://blog.wallaroolabs.com
[codemesh16 how did i get here]: https://www.youtube.com/watch?v=6MsPDtpe2tg
[community website]: http://www.wallaroolabs.com/community
[contact us email]: mailto:hello@wallaroolabs.com
[contribute section]: #how-to-contribute
[contributors guide]: CONTRIBUTING.md
[current limitations]: LIMITATIONS.md
[developer mailing list]: https://groups.io/g/wallaroo
[documentation section]: #documentation
[documentation website]: http://docs.wallaroolabs.com
[exactly-once website]: http://www.wallaroolabs.com/technology/exactly-once
[FAQ]: http://www.wallaroolabs.com/faq
[getting help section]: #getting-help
[getting started section]: #getting-started
[hello wallaroo post]: https://blog.wallaroolabs.com/2017/03/hello-wallaroo/
[IRC]: https://webchat.freenode.net/?channels=#wallaroo
[license section]: #license
[open issues]: https://github.com/WallarooLabs/wallaroo/issues
[open sourcing wallaroo]: https://blog.wallaroolabs.com/2017/09/open-sourcing-wallaroo/
[pony examples]: examples/pony
[qcon16 how did i get here]: https://www.infoq.com/presentations/trust-distributed-systems
[scale independence with wallaroo]: https://vimeo.com/234753585
[resilience website]: http://www.wallaroolabs.com/technology/exactly-once
[roadmap]: ROADMAP.md
[secret sauce post]: https://blog.wallaroolabs.com/2017/06/whats-the-secret-sauce/
[state management website]: http://www.wallaroolabs.com/technology/state-management
[status section]: #status
[twitter]: https://www.twitter.com/wallaroolabs
[unstable documentation website]: https://www.gitbook.com/book/wallaroo-labs/wallaroo-latest/details
[wallaroo community license]: LICENSE.md
[wallaroo labs website]: https://www.wallaroolabs.com
[what is wallaroo section]: #what-is-wallaroo
