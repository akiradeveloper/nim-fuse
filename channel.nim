import posix
import os
import protocol

include Buf

type fuse_args = object
  argc: cint
  argv: cstringArray
  allocated: cint

proc fuse_mount_compat25(mountpoint: cstring, args: ptr fuse_args): cint {. importc .}
proc fuse_unmount_compat22(mountpoint: cstring) {. importc .}

type Channel* = ref object 
  mount_point: string
  fd: cint

proc connect*(mount_point: string, mount_options: openArray[string]): Channel =
  var args = fuse_args (
    argc: cast[cint](len(mount_options)),
    argv: allocCStringArray(mount_options),
    allocated: 0, # control freeing by ourselves
  )
  let fd = fuse_mount_compat25(mount_point, addr(args))
  deallocCStringArray(args.argv)
  Channel(mount_point:mount_point, fd:fd)

proc disconnect*(chan: Channel) =
  fuse_unmount_compat22(chan.mount_point)

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

proc send(self: Channel, bufs: openArray[Buf]): int =
  let n = cast[cint](len(bufs))
  var iov = newSeq[TIOVec](n)
  for i in 0..n-1:
    iov[i].iov_base = bufs[i].asPtr
    iov[i].iov_len = len(bufs[i])
  posix.writev(self.fd, addr(iov[0]), n)

when isMainModule:
  let ch = channel.connect("/mnt", @[])
  disconnect(ch)
