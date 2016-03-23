use "ponytest"

actor TestMain is TestList
  new create(env: Env) => PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(_TestSenderMessageConstruction)
    test(_TestSentLogEncoder)

class iso _TestSenderMessageConstruction is UnitTest
  """
  Test that our sender is correctly taking data and returning a properly
  formatted message that we can send on its merry way
  """
  fun name(): String => "giles/sender:SenderMessageConstruction"

  fun apply(h: TestHelper) =>
    let encoder = Encoder

    let hello_world = encoder("Hello World")
    h.assert_eq[String](hello_world, "1FPUT:Hello World")

    let hello_walken= encoder("Hello, World: The Christopher Walken Story")
    h.assert_eq[String](hello_walken,
    "22EPUT:Hello, World: The Christopher Walken Story")

    let one = encoder("1")
    h.assert_eq[String](one, "15PUT:1")

    let ten = encoder("10")
    h.assert_eq[String](ten, "16PUT:10")

    let one_hundred = encoder("100")
    h.assert_eq[String](one_hundred, "17PUT:100")

    let one_thousand = encoder("1000")
    h.assert_eq[String](one_thousand, "18PUT:1000")

class iso _TestSentLogEncoder is UnitTest
  """
  Verify that the giles sender log encoder is encoding individual lines as
  expected
  """
  fun name(): String => "giles/sender:SentLogEncoder"

  fun apply(h: TestHelper) =>
    let encoder = SentLogEncoder

    let hello_world = encoder(("Hello World", 95939399))
    h.assert_eq[String](hello_world,"95939399, Hello World")

    let hello_walken= encoder(("Hello, World: The Christopher Walken Story",
    23123213))
    h.assert_eq[String](hello_walken,
    "23123213, Hello, World: The Christopher Walken Story")

    let one = encoder(("1", 1))
    h.assert_eq[String](one, "1, 1")

    let ten = encoder(("10", 2))
    h.assert_eq[String](ten, "2, 10")

    let one_hundred = encoder(("100", 3))
    h.assert_eq[String](one_hundred, "3, 100")

    let one_thousand = encoder(("1000", 4))
    h.assert_eq[String](one_thousand, "4, 1000")
