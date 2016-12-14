use "wallaroo/fail"

interface CreditReceiver
  fun ref receive_credits(credits: ISize)

class EmptyCreditReceiver
  fun ref receive_credits(credits: ISize) =>
    Fail()
