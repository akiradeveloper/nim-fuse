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

proc send(req: Request, e: int):
  sendIOV(req, e, &[])

proc send[T](req: Request, e: int, o: T):
  sendIOV(req, e, &[TIOVec(io_base:addr(o), io_len:sizeof(T))])

proc replyIOV*(req: Request, iov: openArray[TIOVec]):
  sendIOV(req, 0, iov)

proc replyOk*(req: Request):
  send(req, 0)

proc replyErr*(req: Request, int err):
  send(req, -err)
