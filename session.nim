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

proc mkSession[FS:Filesystem](fs:FS, chan: Channel): Session =
  Session (
    fs: fs,
    chan: chan,
    initialized: false,
    destroyed: false,
  )

proc exists(self: Session): bool =
  not self.destroyed

proc loop(self: Session) =
  let
    MAX_WRITE_BUFSIZE* = 16 * 1024 * 1024
  # Always alloc max sized buffer but 100 bytes as safety mergin
  var buf = mkBuf(MAX_WRITE_BUFSIZE + 100)
  while self.exists:
    let err = self.chan.fetch(buf)
    if unlikely(err):
      # TODO
      # ENODEV -> quit the loop by set 1 to se.destroyed
      discard
    else:
      # Now the buffer is valid
      dispatch(self.chan, buf)
