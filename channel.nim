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

proc fetch(chan: Channel, buf: Buf) =
  discard

type Sender* = ref object
  fd: cint

proc mkSender(chan: Channel): Sender =
  Sender(fd: chan.fd)

proc send(self: Sender, buf: Buf) =
  discard
