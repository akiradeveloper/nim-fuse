# fuse_lowlevel.h describes the reply protocols

import posix
import protocol
import request

type Reply = ref object

proc sendIOV(req: Request, e: int, iov: openArray[TIOVec]):
  var bufs = newSeq[Buf](len(iov) + 1)
  var outH: fuse_out_header
  outH.unique = req.header.unique
  outH.error = e
  var l = sizeof(fuse_out_header)
  for i, io in iov:
    l += io.io_len
    bufs[i+1] = mkBuf(io.iov_base, io.io_len)
  outH.len = l
  bufs[0] = mkBuf[fuse_out_header](outH)
  req.chan.send(bufs)

proc send[T](req: Request, e: int, o: T):
  sendIOV(req, e, &[TIOVec(io_base:addr(o), io_len:sizeof(T))])

proc send(req: Request, e: int):
  sendIOV(req, e, &[])

proc iov*(req: Request, iov: openArray[TIOVec]):
  sendIOV(req, 0, iov)

proc ok*[T](req: Request, o: T):
  send(req, 0, o)

proc err*(req: Request, err: int):
  send(req, -err)

proc readlink*(req: Request, linkname: string):
  ok(req, linkname)

proc none*():
  discard

proc entry*():
  discard

proc attr*():
  discard

proc open*():
  discard

proc write*():
  discard

proc buf*():
  discard

proc data*():
  discard

proc statfs:():
  discard

proc xattr():
  discard

proc lock():
  discard

proc bmap():
  discard

proc ioctl_retry():
  discard

proc ioctl():
  discard

proc ioctl_iov():
  discard

proc poll():
  discard
