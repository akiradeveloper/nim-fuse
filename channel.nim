include Buf

type fuse_args = object
  argc: cint
  argv: ptr ptr cchar
  allocated: cint

proc fuse_mount_compat25(mountpoint: cstring, args: ptr fuse_args): cint {. importc .}

type Channel* = ref object 
  fd: cint

proc newChannel(mountpoint, options):Channel =
  discard

proc receive(chan: Channel, buf: Buf) =
  discard

type Send* = ref object
  fd: cint

proc mkSend(chan: Channel): Send =
  Send(fd: chan.fd)

proc run(self: Send, buffer) =
  discard
