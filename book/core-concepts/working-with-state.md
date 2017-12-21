# Working with State

Wallaroo's state objects allow developers to define their own domain-specific data structures that Wallaroo manages. These state objects are used to store state in running application. They provide safe, serialized access to data in a highly parallelized environment. In "Working in State", we are going to take you through how you can operate on your state objects.

## State computations

Imagine a word counting application. We'll have a state object for each different word. Each word and count object would look something like:

{% codetabs name="Python", type="py" -%}
class WordAndCount(object):
    def __init__(self, word="", count=0):
        self.word = word
        self.count = count
{%- language name="Go", type="go" -%}
type WordAndCount struct {
  Word string
  Count uint64
}
{%- endcodetabs %}

State computations allow you to read and write data to state objects. State computations have 3 inputs and 2 outputs. 

* State computation input:
  - The message to be processed
  - The state object we are operating on
  - A state change repository
* State computation output:
  - An optional output message
  - An optional state change

For the duration of this document, we're going to ignore the "state change repository" input and "optional state change" output as they are used by Wallaroo's resilience feature and you don't need to understand them to grasp the basics of how Wallaroo's state computations work. Remember when we said that state objects provide "safe, serialized access to data in a highly parallelized environment"? Let's take a look at what that means. 

## Thread Safety

When a state computation is running, one of the parameters it is provided is the state to operate on. That state will only be provided to a single state computation at a time. Within the state computation, you don't have to worry about thread synchronization issues. 
