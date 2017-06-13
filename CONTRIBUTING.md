# Contributing

## Public Visibility

*DO NOT COMMIT ANYTHING YOU/WE DO NOT WANT BECOMING PUBLIC LATER*.

At this time, this repo is private and not open to the public. However, at some point, we are going to open source all/parts of Buffy. The easiest way to do that is to switch this repo from private to public. It is entirely possible that anything you commit now will be made public later in commit comments, history, etc. 

## Commit Messages

Before contributing any code to this repo, please read [How to Write a Git Commit Message](http://chris.beams.io/posts/git-commit/). And then, follow it. And remember, if you have time to commit code, you have time to write a good commit message; that includes you, Sean.

## Code Formatting

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

### Pony

All Pony sources should follow the [Pony standard library style guide](https://github.com/ponylang/ponyc/blob/master/STYLE_GUIDE.md).

### Python

All Python sources should follow [PEP-8 formatting](https://www.python.org/dev/peps/pep-0008/).

## Documentation

As much as possible all documentation should be textual and in Markdown format. Diagrams are often needed to clarify a point. For any images, an original high-resolution source should be provided as well so updates can be made.

Documentation is not "source code." As such, it should not be wrapped at 80 columns. Documentation should be allowed to flow naturally until the end of a paragraph. It is expected that the reader will turn on soft wrapping as needed.

### Code Examples in documentation

All code examples in documentation should be formatted in a fashion appropriate to the language in question.

### Commands in documentation

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
