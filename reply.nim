# fuse_lowlevel.h describes the reply protocols

import posix
import protocol
import request

type Sender = ref object of RootObj
proc send(self: Sender):
  discard

type Raw = ref object
  unique: uint64
  sender: Sender
  data: openArray[Buf]
proc newReplyRaw(sender: Sender, unique: uint64): ReplyRaw =
  discard
proc ack(self: ReplyRaw, err: int, dataSeq: openArray[Buf]) =
  var bufs = newSeq[Buf](len(dataSeq) + 1)
  var l = sizeof(fuse_out_header)
  for i, data in dataSeq:
    bufs[i+1] = dataSeq[i]
  var outH: fuse_out_header
  outH.unique = self.unique
  outH.error = e
  outH.len = l
  bufs[0] = mkBuf[fuse_out_header](outH)
  sender.send(bufs)
proc ok(self: ReplyRaw, dataSeq: openArray[Buf]) =
  self.ack(0, dataSeq)
proc err(self: ReplyRaw, err: int) =
  self.ack(e, @[])

type ReplyOk = ref object
  raw: Raw
proc newOk(sender: Sender, unique: uint64): ReplyOk =
  ReplyOk(raw: newReplyRaw(sender, unique))
proc ok(self: ReplyOk) =
  self.raw.ok()

type IOV = ref object
  raw: Raw
proc newIOV(sender: Sender, unique: uint64): ReplyIOV =
  IOV(raw: newRaw(sender, unique))
proc ok(self: ReplyIOV, iov: openArray[TIOVec]) =
  discard

type Readlink = ref object
  raw: Raw
proc newReadlink(sender: Sender, unique: uint64) =
  Readlink(raw: newRaw(sender, unique))
proc ok(self: Readlink, link: string) =
  self.raw.ok([mkBuf[string](link)])

type None = ref object
  raw: Raw
proc newNone(sender: Sender, unique: uint64) =
  None(raw: newRaw(sender, unique))
proc ok(self: Readlink) =
  self.raw.ok([])

type Entry = ref object
proc newEntry*():
  discard

type Attr = ref object
proc newAttr*():
  discard

type Open = ref object
proc newOpen*():
  discard

type Write = ref object
proc newWrite*():
  discard

type Buf = ref object
proc newBuf*():
  discard

type Data = ref object
proc newData*():
  discard

type Statfs = ref object
proc newStatfs:():
  discard

type XAttr = ref object
proc newXAttr():
  discard

type Lock = ref object
proc newLock():
  discard

type Bmap = ref object
proc newBmap():
  discard

# TODO
proc ioctl_retry():
  discard

proc ioctl():
  discard

proc ioctl_iov():
  discard

proc poll():
  discard
