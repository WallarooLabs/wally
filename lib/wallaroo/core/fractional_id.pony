use "collections"

type FractionalMessageId is (Array[U32] val | None)

// TODO: remove this when done debugging fractional ids recovery
primitive FractionalMessageIdToString
  fun apply(frac_ids: FractionalMessageId): String val =>
    match frac_ids
    | None =>
      "None"
    | let f: Array[U32] val =>
      let a = recover iso Array[String] end
      for v in f.values() do
        a.push(v.string())
      end
      ",".join(consume a)
    else
      "FAILED TO STRINGIFY FractionalMessageId"
    end
