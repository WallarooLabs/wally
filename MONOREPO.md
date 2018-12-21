# Application Structure

Wallaroo currently exists as a mono-repo. All the source that makes Wallaroo go is in this repo. Let's take a quick walk through what you'll find in each top-level directory:

#### book/
Markdown source used to build http://docs.wallaroolabs.com. http://docs.wallaroolabs.com gets built from the latest commit to the release branch.

#### examples/

Wallaroo example applications in a variety of languages. Currently, only the Python API examples are supported.

#### giles/

TCP utility applications that can stream data over TCP to Wallaroo applications and receive TCP streams from said applications.

#### lib/

The Pony source code that makes up Wallaroo.

#### machida/

Python runner application. Machida embeds a Python interpreter inside a native Wallaroo binary and allows you to run applications using the Wallaroo Python API.

#### monitoring hub/

Source for the Wallaroo metrics UI.

#### orchestration/

Tools we use to create machines in AWS and other environments.

#### testing/

Tools we have written that are used to test Wallaroo.

#### utils/

End user utilities designed to make it easier to do various Wallaroo tasks like cleanly shut down a cluster.
