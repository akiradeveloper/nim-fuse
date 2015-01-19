import channel

type Request* = ref object
  chan: Channel
  buf: Buf # a buffer received

proc mkRequest*(chan: Channel, buf: Buf): Request =
  discard

proc handle(self: Request) =
  discard
