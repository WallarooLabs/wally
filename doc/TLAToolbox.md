# TLA+ Toolbox

## Installing

On OSX, install TLA+ Toolbox by running

```brew cask install tla-plus-toolbox```.

You can also follow the instructions in the "Downloading the Toolbox" section of:
http://research.microsoft.com/en-us/um/people/lamport/tla/toolbox.html

Now install TLAPS, the TLA+ Proof System:
http://tla.msr-inria.inria.fr/tlaps/content/Download/Binaries.html

You'll need to add /usr/local/bin to your $PATH.

If you want to be able to output PDF versions of you specifications, you'll need pdflatex. For OSX, install MacTeX from:
https://tug.org/mactex/mactex-download.html

Freshly impressed by how long that download takes, run the downloaded
pkg file in order to install MacTeX. You'll need to add /usr/texbin to your $PATH if you want to run LaTeX tools like pdflatex from the command
line.

## Configuring

Load up TLA+ Toolbox and marvel at its weird, outdated logo and interface.

In order to enable TLAPS, add /usr/local/lib/tlaps to the toolbox's library path (File->Preferences->TLA+ Preferences->Add Directory).

In order to enable PDF creation, set the PDF Viewer to /usr/texbin/pdflatex (File->Preferences->TLA+ Preferences->PDF Viewer->Specify pdflatex command)

## Using

A lot of the action will be in creating and running models to see if
there is an error in your spec.
