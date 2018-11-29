# Contributing

You want to contribute to Wallaroo? Awesome.

There are a number of ways to contribute to Wallaroo. As this document is a little long, feel free to jump to the section that applies to you currently:

* [Bug report](#bug-report)
* [How to contribute](#how-to-contribute)
* [Pull request](#pull-request)

Additional notes regarding formatting:

* [Documentation formatting](#documentation-formatting)
* [Code formatting](#code-formatting)
* [Standard Library File Naming](#standard-library-file-naming)

## Bug report

First of all please [search existing issues](https://github.com/wallaroolabs/wallaroo/issues) to make sure your issue hasn't already been reported. If you cannot find a suitable issue — [create a new one](https://github.com/WallarooLabs/wallaroo/issues/new).

Provide the following details:

  - short summary of what you were trying to achieve,
  - a code snippet causing the bug,
  - expected result,
  - actual results and
  - environment details: at least operating system version

If possible, try to isolate the problem and provide just enough code to demonstrate it. Add any related information which might help to fix the issue.

## How to Contribute

We use a fairly standard GitHub pull request workflow. If you have already contributed to a project via GitHub pull request, you can skip this section and proceed to the [specific details of what we ask for in a pull request](#pull-request). If this is your first time contributing to a project via GitHub, read on.

Here is the basic GitHub workflow:

1. Fork the Wallaroo repo. you can do this via the GitHub website. This will result in you having your own copy of the Wallaroo repo under your GitHub account.
2. Clone your Wallaroo repo to your local machine
3. Make a branch for your change
4. Make your change on that branch
5. Push your change to your repo
6. Use the github ui to open a PR

Some things to note that aren't immediately obvious to folks just starting out:

1. Your fork doesn't automatically stay up to date with changes in the main repo.
2. Any changes you make on your branch that you used for one PR will automatically appear in another PR so if you have more than 1 PR, be sure to always create different branches for them.
3. Weird things happen with commit history if you don't create your PR branches off of `master` so always make sure you have the `master` branch checked out before creating a branch for a PR

If you feel overwhelmed at any point, don't worry, it can be a lot to learn when you get started. Feel free to reach out via [IRC](https://webchat.freenode.net/?channels=%wallaroo) or the [Wallaroo mailing list](https://groups.io/g/wallaroo) for assistance.

You can get help using GitHub via [the official documentation](https://help.github.com/). Some hightlights include:

- [Fork A Repo](https://help.github.com/articles/fork-a-repo/)
- [Creating a pull request](https://help.github.com/articles/creating-a-pull-request/)
- [Syncing a fork](https://help.github.com/articles/syncing-a-fork/)

## Pull request

*Note*: You must sign our [Contributor License Agreement](https://gist.github.com/WallarooLabsTeam/e06d4fed709e0e7035fdaa7249bf88fb) (CLA) before your pull request can be accepted. You can [sign the CLA now](https://cla-assistant.io/wallaroolabs/wallaroo), or you can wait until you submit a pull request, at which point you will be prompted to sign it. Your pull request cannot be accepted until you have signed the CLA.

Before issuing a pull request, we ask that you squash all your commits into a single logical commit. While your PR is in review, we may ask for additional changes, please do not squash those commits while the review is underway. Once everything is good, we'll then ask you to further squash those commits before merging. We ask that you not squash while a review is underway as it can make it hard to follow what is going on. 

If you are making an extensive change, please ensure that an [issue has been created](https://github.com/wallaroolabs/wallaroo/issues) for the work first. If there isn't one, please [create an issue](https://github.com/WallarooLabs/wallaroo/issues/new) before you start. 

Additionally, we ask that you:

* [Write a good commit message](http://chris.beams.io/posts/git-commit/)
* Issue 1 Pull Request per feature. Don't lump unrelated changes together.

If you aren't sure how to squash multiple commits into one, Steve Klabnik wrote [a handy guide](http://blog.steveklabnik.com/posts/2012-11-08-how-to-squash-commits-in-a-github-pull-request) that you can refer to.

Once those conditions are met, the PR can be merged.

Please note, if your changes are purely to things like README, CHANGELOG etc, you can add [skip ci] as the last line of your commit message and your PR won't be run through our continuous integration systems. We ask that you use [skip ci] where appropriate as it helps to get changes through CI faster and doesn't waste resources that TravisCI is kindly donating to the Open Source community.

## Documentation formatting

When contributing to documentation, try to keep the following style guidelines in mind:

As much as possible all documentation should be textual and in Markdown format. Diagrams are often needed to clarify a point. For any images, an original high-resolution source should be provided as well so updates can be made.

Documentation is not "source code." As such, it should not be wrapped at 80 columns. Documentation should be allowed to flow naturally until the end of a paragraph. It is expected that the reader will turn on soft wrapping as needed.

All code examples in documentation should be formatted in a fashion appropriate to the language in question.

All command line examples in documentation should be presented in a copy and paste friendly fashion. Assume the user is using the `bash` shell. GitHub formatting on long command lines can be unfriendly to copy-and-paste. Long command lines should be broken up using `\` so that each line is no more than 80 columns. Wrapping at 80 columns should result in a good display experience in GitHub. Additionally, continuation lines should be indented two spaces.

OK:

```bash
my_command --some-option foo --path-to-file ../../wallaroo/long/line/foo \
  --some-other-option bar
```

Not OK:

```bash
my_command --some-option foo --path-to-file ../../wallaroo/long/line/foo --some-other-option bar
```

Wherever possible when writing documentation, favor full command options rather than short versions. Full flags are usually much easier to modify because the meaning is clearer.

OK:

```bash
my_command --messages 100
```

Not OK:

```bash
my_command -m 100
```

## Code formatting

The basics:

* Indentation

We indent using spaces, not tabs. Indentation is language specific.

* Watch your whitespace!

Use an editor plugin to remove unused trailing whitespace including both at the end of a line and at the end of a file. By the same token, remember to leave a single newline only line at the end of each file. It makes output files to the console much more pleasant.

* Line Length

We all have different sized monitors. What might look good on yours might look like awful on another. Be kind and wrap all lines at 80 columns unless you have a good reason not to.

* Reformatting code to meet standards

Try to avoid doing it. A commit that changes the formatting for large chunks of a file makes for an ugly commit history when looking for changes. Don't commit code that doesn't conform to coding standards in the first place. If you do reformat code, make sure it is either standalone reformatting with no logic changes or confined solely to code whose logic you touched. For example, updating the indentation in a file? Do not make logic changes along with it. Editing a line that has extra whitespace at the end? Feel free to remove it.

The details:

All Pony sources should follow the [Pony standard library style guide](https://github.com/ponylang/ponyc/blob/master/STYLE_GUIDE.md).

All Python sources should follow [PEP-8 formatting](https://www.python.org/dev/peps/pep-0008/).

##  File naming

Our Pony code follows the [Pony standard library file naming guidelines](https://github.com/ponylang/ponyc/blob/master/STYLE_GUIDE.md#naming).
