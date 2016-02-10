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

## Model Checking

Click (TLC Model Checker->New Model) to create a new model. When creating a model, you will be assigning values 
to the constants declared in your spec.  Within the model tab (with label corresponding to the name of the model),
you can assign values to constants in the "What is the model?" section.

Look at the bottom left of the "Model Overview" tab under "What to Check". This is where you set up what you want 
to check when running the model. The first thing you should determine is whether you expect your spec to terminate. 
If so, deselect "Deadlock", since termination will be interpreted as deadlock. 

Run the model checker by clicking the green play button in the top left of the model tab. If you want more detailed
output, click (TLC Model Checker->TLC Console) to see the console.

## Experimenting With Expressions

One way that might help you understand TLA+ better is to play around with the expression evaluator in the Model
Checker. Your expressions will be evaluated in the context of the corresponding Specification.

Open a model and click on the "Model Checking Results" tab.  Type a TLA+ expression in the Expression field
and click the play button. TLC will evaluate the expression and print the result in the Value field.  For example, 
the result of evaluating the expression {"a"} \cup {"b"} is {"a", "b"}.

## Notes on TLA+

TLA+ is currently on version 2. However, the best source on the language, the book Specifying Systems, describes TLA+1. 
The changes between the two versions are described here: http://research.microsoft.com/en-us/um/people/lamport/tla/tla2.html

