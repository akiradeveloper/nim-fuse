import channel

type Request* = ref object
  sender: Sender # sender to reply
  buf: Buf # a buffer received

proc mkRequest*(sender: Sender, buf: Buf): Request =
  discard
