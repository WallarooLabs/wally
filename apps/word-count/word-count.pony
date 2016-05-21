use "collections"
use "buffy"
use "buffy/messages"
use "buffy/metrics"
use "buffy/topology"
use "net"

actor Main
  new create(env: Env) =>
    try
      let topology: Topology val = recover val
        Topology
          .new_pipeline[String, WordCount val](P, S)
          .and_then_map[WordCount val](
            lambda(): MapComputation[String, WordCount val] iso^ => Split end)
          .and_then_stateful_partition[WordCount val, WordCountTotals](
            lambda(): StateComputation[WordCount val,
                                       WordCount val,
                                       WordCountTotals] iso^ => Count end,
            lambda(): WordCountTotals => WordCountTotals end,
            FirstLetterPartition)
          .build()
      end
      Startup(env, topology, 1)
    else
      env.out.print("Couldn't build topology")
    end

class Split is MapComputation[String, WordCount val]
  fun name(): String => "split"
  fun apply(d: String): Seq[WordCount val] =>
    let counts: Array[WordCount val] iso = recover Array[WordCount val] end
    for word in d.split(" ").values() do
      counts.push(WordCount(word.lower(), 1))
    end
    consume counts

class Count is StateComputation[WordCount val, WordCount val, WordCountTotals]
  fun name(): String => "count"
  fun ref apply(state: WordCountTotals, d: WordCount val): WordCount val =>
    state(d)

class WordCount
  let word: String
  let count: U64
  
  new val create(w: String, c: U64) =>
    word = w
    count = c

class WordCountTotals
  let words: Map[String, U64] = Map[String, U64]

  fun ref apply(value: WordCount val): WordCount val =>
    try
      words(value.word) = words(value.word) + value.count
      WordCount(value.word, words(value.word))
    else
      words(value.word) = value.count
      value
    end

class FirstLetterPartition is PartitionFunction[WordCount val]
  fun apply(wc: WordCount val): U64 =>
    try wc.word(0).hash() else 0 end

class P
  fun apply(s: String): String =>
    s

class S
  fun apply(input: WordCount val): String =>
    input.word + ":" + input.count.string()
