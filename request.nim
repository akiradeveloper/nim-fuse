import channel

type Request* = ref object
  chan: Channel

proc newRequest*(send: Send, buf: Buf): Request =
  discard
