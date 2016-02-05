# Contributing

## Public Visibility

*DO NOT COMMIT ANYTHING YOU/WE DO NOT WANT BECOMING PUBLIC LATER*.

At this time, this repo is private and not open to the public. However, at some
point we are going to open source all/parts of Buffy. The easiest way to do that
is to switch this repo from private to public. It is entirely possible that
anything you commit now will be made public later in commit comments, history
etc. 

## Commit Messages

Before contributing any code to this repo, please read 
[How to Write a Git Commit Message](http://chris.beams.io/posts/git-commit/).
And then, follow it. And remember, if you have time to commit code, you have
time to write a good commit message; that includes you Sean.

## Code Formatting

* Indentation

We indent using spaces not tabs. Indentation is language specific: 2 spaces for
Pony, 4 spaces for Python.

* Watch your whitespace!

Use an editor plugin to remove unused trailing whitespace. This includes both at
the end of a line and at the end of a file. By the same token, remember to leave
a single newline only line at the end of each file. It makes output files to the
console much more pleasant.

* Line Length

We all have different sized monitors. What might look good on yours might look
like awful on another. Be kind and wrap all lines at 80 columns unless you
have a good reason not to.

* Reformatting code to meet standards

Try to avoid doing it. A commit that changes the formatting for large chunks of
a file makes for an ugly commit history when looking for important changes. This
means, don't commit code that doesn't conform to coding standards in the first
place. If you do reformat code, make sure it is either standalone reformatting
with no logic changes or confined solely to code whose logic you touched. For
example, changing the indentation in a file? Do not make logic changes along
with it. Editing a line that has extra whitespace at the end? Feel free to
remove it.

## Documentation

All documentation, be it textual, visual or what not, should include sources for
that documentation so that anyone else can easily make modifications. For example,
don't check in documentation in pdf format or as a png image.

### Appropriate Formats

* Textual

We have 2 approved documentation formats. Markdown for simple documentation like
this won't be repurposed for other mediums and org-mode format. Org-mode is used
by more than 1 team member and makes a great end format medium. It is displayed
with some decent formatting in GitHub and can be turned into PDF and a variety
of other formats. Additionally, you can do basic org-mode format editing in any
text editor although Emacs using org-mode is by far the best editor for handling
it. 

* Visual

We've yet to settle on a source format for images, drawing etc.  
