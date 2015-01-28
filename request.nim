import protocol
import channel

type Request* = ref object
  chan: Channel
  buf: Buf # a buffer received

  # copy from fuse_in_header
  # see fuse_ll_process_buf
  # uid: uint32
  # gid: uint32
  # pid: uint32
  # unique: uint64
  header: fuse_in_header
  data: Buf

proc dispatch*(chan: Channel, buf: Buf) =
  discard
