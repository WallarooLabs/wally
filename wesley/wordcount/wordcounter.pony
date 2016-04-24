use "collections"

class WordCounter is Equatable[WordCounter]
  let counts: Map[String, U64] = Map[String,U64]()
  let _punctuation: String = """!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~"""
 
  fun eq(that: box->WordCounter): Bool =>
    true

  fun ref apply(key': String): (U64|None) =>
    """Increment the value of key by 1. Create it if necessary."""
    let key = clean(key')
    if key == "" then return None end
    try
      counts.update(key, counts(key)+1)
    else
      counts.update(key, 1)
    end

  fun clean(s: String): String =>
    """Strip characters based on a rule."""
    let charset = _punctuation
    recover val s.clone().lower().strip(charset) end

  fun ref update_from_string(s: String) =>
    for line in s.split("\n").values() do
      for word in line.split(" ").values() do
        apply(word)
      end
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


