import lowlevel
import protocol
import channel
import request

type Session* = ref object 
  fs: LowlevelFs
  chan: Channel
  proto_major: uint32
  proto_minor: uint32
  initialized: bool
  destroyed: bool

proc mkSession*(fs:LowlevelFs, chan: Channel): Session =
  Session (
    fs: fs,
    chan: chan,
    initialized: false,
    destroyed: false,
  )

# will be removed
proc exists(self: Session): bool =
  not self.destroyed

let
  MAX_WRITE_BUFSIZE* = 16 * 1024 * 1024

proc processBuf(self: Session, buf: Buf) =
  var hd = pop[fuse_in_header](buf)
  var req = Request (
    se: self,
    header: hd,
    data: buf.asBuf
  )
  req.dispatch()

proc loop*(self: Session) =
  # Always alloc max sized buffer but 100 bytes as safety mergin
  var buf = mkBuf(MAX_WRITE_BUFSIZE + 100)
  while self.exists:
    let err = self.chan.fetch(buf)
    if unlikely(err != 0):
      # TODO
      # ENODEV -> quit the loop by set 1 to se.destroyed
      discard
    else:
      self.processBuf(buf)

proc mount*(fs: LowlevelFs, mountpoint: string, options: openArray[string]) =
  let chan = connect(mountpoint, options)
  let se = mkSession(fs, chan)
  se.loop
  disconnect(chan)
