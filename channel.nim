import posix
import protocol

include Buf

type fuse_args = object
  argc: cint
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
    return -1 # FIXME
  elif n < 0:
    return n

  let header = pop[fuse_in_header](buf)
  let remained_len = cast[int](header.len) - header_sz
  let n2 = posix.read(chan.fd, buf.asPtr, remained_len)
  if (n2 < remained_len):
    return -1 # FIXME
  
  return 0

type Sender* = ref object
  fd: cint

proc mkSender(chan: Channel): Sender =
  Sender(fd: chan.fd)

proc send(self: Sender, buf: Buf) =
  discard
