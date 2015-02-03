{. passC: gorge("pkg-config --cflags fuse") .}
{. passL: gorge("pkg-config --libs fuse") .}

import reply
import posix
import os
import protocol
import Buf
import logging

type fuse_args {. importc:"struct fuse_args", header:"<fuse.h>" .} = object
  argc: cint
  argv: cstringArray
  allocated: cint

# type fuse_chan {. importc:"struct fuse_chan", header:"<fuse.h>" .} = object

proc fuse_mount_compat25(mountpoint: cstring, args: ptr fuse_args): cint {. importc, header:"<fuse.h>" .}
proc fuse_unmount_compat22(mountpoint: cstring) {. importc, header: "<fuse.h>" .}

# proc fuse_mount(mountpoint: cstring, args: ptr fuse_args): ptr fuse_chan {. importc, header:"<fuse.h>" .}
# proc fuse_unmount(mountpoint: cstring, ch: ptr fuse_chan) {. importc, header:"<fuse.h>" .}
# proc fuse_chan_fd(ch: ptr fuse_chan): cint {. importc, header:"<fuse.h>" .}

type Channel* = ref object 
  mount_point: string
  fd: cint
  # raw_chan: ptr fuse_chan

proc connect*(mount_point: string, mount_options: openArray[string]): Channel =
  var args = fuse_args (
    argc: mount_options.len.cint,
    argv: allocCStringArray(mount_options),
    allocated: 0, # control freeing by ourselves
  )
  let fd = fuse_mount_compat25(mount_point, addr(args))
  debug("fd:$1", fd)
  # let ch = fuse_mount(mount_point, addr(args))
  deallocCStringArray(args.argv)
  # Channel(mount_point:mount_point, fd:fuse_chan_fd(ch), raw_chan:ch)
  Channel(mount_point:mount_point, fd:fd)

proc disconnect*(chan: Channel) =
  fuse_unmount_compat22(chan.mount_point)
  # use_unmount(chan.mount_point, chan.raw_chan)

# Read /dev/fuse into a provided buffer
# success: 0
# failure: error value (< 0)
proc fetch*(chan: Channel, buf: Buf): int =
  assert(buf.pos == 0)

  debug("-------------------------------------------------")
  debug("fetch start. fd:$1", chan.fd)
  let n = posix.read(chan.fd, buf.asPtr, buf.size)
  debug("fetch end. n:$1", n)
  if n > 0:
    buf.size = n # drop remaining buffer
    result = 0
  else:
    result = osLastError().int
  debug("result:$1", result)

type ChannelSender* = ref object of Sender
  chan: Channel

method send*(self: ChannelSender, dataSeq: openArray[Buf]): int =
  let n = dataSeq.len.cint
  var iov = newSeq[TIOVec](n)
  var sumLen = 0
  for i in 0..n-1:
    let data = dataSeq[i]
    iov[i].iov_base = data.asPtr
    iov[i].iov_len = data.size
    sumLen += data.size
  debug("ChannelSender.send. fd:$1, n:$2", self.chan.fd, n)
  let bytes = posix.writev(self.chan.fd, addr(iov[0]), n)
  if bytes != sumLen:
    debug("send NG. actual:$1byte, expected:$2", bytes, sumLen)
    result = -posix.EIO
  else:
    debug("send OK")
    result = 0

proc mkSender*(self: Channel): ChannelSender =
  ChannelSender(chan: self)

when isMainModule:
  let ch0 = channel.connect("./mnt0", @[])
  let ch1 = channel.connect("./mnt1", @[])
  disconnect(ch0)
  disconnect(ch1)
