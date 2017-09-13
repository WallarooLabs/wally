/*

Copyright 2017 The Wallaroo Authors.

Licensed as a Wallaroo Enterprise file under the Wallaroo Community
License (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at

     https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

*/

use ".."
use "collections"

class WordCounter is CanonicalForm
  let counts: Map[String, U64] = Map[String,U64]()
  let _punctuation: String = """ !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~ """

  fun apply(key: String): U64 ? =>
    counts(key)

  fun ref update(key': String, value: U64) =>
    let key = clean(key')
    if key == "" then return end
    counts(key) = value

  fun ref update_from_string(s: String) =>
    for line in s.split("\n").values() do
      for word in line.split(_punctuation).values() do
        _increment_word(word)
      end
    end

  fun ref _increment_word(word': String) =>
    let word = lower(word')
    if word == "" then return end
    try
      counts(word) = counts(word) + 1
    else
      counts(word) = 1
    end

  fun compare(that: CanonicalForm): (MatchStatus val, String) =>
    match that
    | let wc: WordCounter =>
      if counts.size() != wc.counts.size() then
        return (ResultsDoNotMatch, "Count map sizes do not match up.")
      end
      for (key, count) in counts.pairs() do
        try
          if count != wc(key) then
            let msg = "Expected " + key + " to have a count of "
              + count.string() + " instead of " + wc(key).string()
  					return (ResultsDoNotMatch, msg)
  				end
        else
          let msg = "Couldn't find " + key + " in results."
          return (ResultsDoNotMatch, msg)
        end
      end
      (ResultsMatch, "")
    else
      (ResultsDoNotMatch, "")
    end

  fun clean(s: String): String =>
    """Strip characters based on a rule."""
    let charset = _punctuation
    recover val s.clone().lower().lstrip(charset).rstrip(charset) end

  fun lower(s: String): String =>
    recover s.lower() end

  fun string(): String =>
    """Return the string representation of the map"""
    var pairs = Array[String]()
    for (word, count) in counts.pairs() do
      pairs.append([word + ": " + count.string()])
    end
    "{ " + ", ".join(pairs) + " }"
