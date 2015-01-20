import posix
import protocol

include Buf

type fuse_args = object
  argc: cint
  # Use cstringArray???
  argv: ptr ptr cchar
  allocated: cint

proc fuse_mount_compat25(mountpoint: cstring, args: ptr fuse_args): cint {. importc .}

type Channel* = ref object 
  fd: cint

proc connect*(mountpoint, options): Channel =
  let fd = fuse_mount_compat25(mountpoint, options) # TODO

proc disconnect*(chan: Channel) =
  discard

# Read /dev/fuse into a provided buffer
# success: 0
# failure: error value (< 0)
proc fetch(chan: Channel, buf: Buf): int =
  buf.initPos
  let header_sz = sizeof(fuse_in_header)
  let n = posix.read(chan.fd, buf.asPtr, header_sz)
  # Read syscall may be interrupted and may return before full read.
  # We handle this case as failure because the the position of cursor
  # in this case isn't defined.
  if (n < header_sz):
    return -posix.EIO
  elif n < 0:
    return n

  let header = pop[fuse_in_header](buf)
  let remained_len = cast[int](header.len) - header_sz
  let n2 = posix.read(chan.fd, buf.asPtr, remained_len)
  if (n2 < remained_len):
    return -posix.EIO
  
  return 0

proc send(self: Channel, bufs: seq[Buf]): int =
  let n = len(bufs)
  var iov = newSeq[TIOVec](n)
  for i in 0..n-1:
    iov[i].iov_base = bufs[i].asPtr
    iov[i].iov_len = len(bufs[i])
