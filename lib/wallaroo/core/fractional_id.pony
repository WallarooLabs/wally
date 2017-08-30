use "collections"

type MsgId is U128
type FractionalMessageId is (Array[U32] val | None)
type MsgIdAndFracs is (MsgId, FractionalMessageId)
