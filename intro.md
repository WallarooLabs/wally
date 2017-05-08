# About this Guide

Welcome to the developer's guide for Sendence Wallaroo. This document is available in a variety of formats including:

- [On the web](https://sendence.gitbooks.io/wallaroo/content/)
- [PDF](https://www.gitbook.com/download/pdf/book/sendence/wallaroo)
- [ePub](https://www.gitbook.com/download/epub/book/sendence/wallaroo)
- [Mobi](https://www.gitbook.com/download/mobi/book/sendence/wallaroo)

You can open issues and submit pull requests against [our GitHub repo](https://github.com/Sendence/wallaroo). All materials herein are copyrighted 2017 All Rights Reserved by Sendence Solutions LLC and subject to our [Terms and Conditions](book/legal/terms.md).

## About Wallaroo

Wallaroo makes it easy for a developer to write a distributed streaming data application.  We expect developers that use Wallaroo to be experts in their domain, not distributed application architects.

When you take advantage of the Wallaroo library in your project, you get to leverage a variety of distributed streaming data application resources. This functionality includes exactly-once message processing guarantees, resilient state, topology management, and partitioning.

Developers only need to be concerned about domain logic of their particular application, leave the messy distributed application guts to Wallaroo.

## The Purpose Of This Document

This document is currently intended to provide the following:

* An overview of the Wallaroo system
* Information about the C++ and Python APIs
* Walkthroughs of applications created using the C++ and Python APIs

## Intended Audience

We designed this document for programmers that want to jump right in and get started using Wallaroo.  Starting with installing all of the necessary components required for Wallaroo and launching an example application in a local development environment.

Although not required, you will get the most out of this tutorial if you have previous experience with an object-oriented language such as Java or C++.  Additionally, experience with stream processing and distributed computing systems and concepts would be helpful.

The language specific portions of the document, for example, the C++ guide, assume that you have previously developed using the language and are comfortable with setting up a development environment for it.

## Supported development environments

It is currently possible to develop Wallaroo applications on MacOS or Linux. This guide currently has installation instructions for MacOS and Ubuntu Linux. It's assumed if you are using a different Linux distribution that you are able to translate the Ubuntu instructions to your distribution of choice.
