use "collections"

class WordSplitter
  fun apply(s: String): Array[String] =>
    let words: Array[String] = Array[String]
    for word in s.split(" ").values() do
      words.push(word)
    end
    words

class Counter
  let counts: Map[String, U64] = Map[String,U64]()

  fun ref apply(key: String): (U64|None) =>
    """Increment the value of key by 1. Create it if necessary."""
    try
      counts.update(key, counts(key)+1)
    else
      counts.update(key, 1)
    end

  fun ref update_from_array(values: Array[(String, U64)]) =>
    for (word, count) in values.values() do
      update(word, count)
    end

  fun ref update(key: String, count: U64): (U64|None) =>
    counts.update(key, count)

  fun get(key: String): (U64|None) =>
    try
      counts(key)
    else
      None
    end

  fun print_results(env: Env) =>
    for (word, count) in counts.pairs() do
      env.out.print(word + ": " + count.string())
    end
    env.out.print(counts.size().string() + " records returned.")
