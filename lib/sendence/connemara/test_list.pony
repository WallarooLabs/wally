trait TestList
  """
  Source of unit tests for a Connemara object.
  See package doc string for further information and example use.
  """

  fun tag tests(test: Connemara)
    """
    Add all the tests in this suite to the given test object.
    Typically the implementation of this function will be of the form:
    ```pony
    fun tests(test: Connemara) =>
      test(_TestClass1)
      test(_TestClass2)
      test(_TestClass3)
    ```
    """
