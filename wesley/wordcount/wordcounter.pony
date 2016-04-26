use "collections"

class WordCounter is Equatable[WordCounter]
  let counts: Map[String, U64] = Map[String,U64]()
  let _punctuation: String = """ !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~"""

  new create() =>
    this

  new create_from_map(map': Map[String, U64]) =>
    load_from_map(map')

  fun eq(that: box->WordCounter): Bool =>
    // We want to terminate early, so 
    // 1. check size
    if counts.size() != that.counts.size() then return false end
    // 2. iterate through keys
    for (key, count) in counts.pairs() do
      match that.get(key)
      | let count': U64 => 
        if count == count' 
				then continue 
				else 
					return false 
				end
      else
        return false
      end
    end
    // They match!
    true

  fun ref load_from_map(map': Map[String, U64]) =>
    for (key, count) in map'.pairs() do
      counts.update(key, count)
    end

  fun ref clear() =>
    counts.clear()

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
