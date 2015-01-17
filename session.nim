import filesystem
import channel
import request
import kernel

type Session[FS:Filesystem] = ref object 
  fs: FS
  chan: Channel
  proto_major: uint32
  proto_minor: uint32
  initialized: bool
  destroyed: bool

proc newSession(): Session =
  discard

proc handleReq(self: Session, buf: Buf): Request =
  newRequest(self.chan.mkSend, buf)

proc loop(self) =
  var buf = mkBuf(RECOMMENDED_BUFSIZE)
  while true:
    let err = self.chan.receive(buf)
    if err > 0:
      self.handleReq(buf)

# proc setup() =
#   discard
#
# proc teardown() =
#   discard
#
# proc mount() =
#   setup()
#   se.loop
#   teardown()
