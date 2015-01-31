# **************************************
#         Nim binding for FUSE
#        (C) 2015 Akira Hayakawa
# **************************************

type Buf* = ref object
  p: pointer
  size: int
  pos: int

proc mkBuf*(size: int): Buf =
  var data = newSeq[uint8](size)
  Buf(
    p: addr(data),
    size: size,
    pos: 0,
  )

proc mkBuf*(p: pointer, size: int): Buf =
  Buf (
    p: p,
    size: size,
    pos: 0,
  )

# FIXME
proc mkBuf*[T](obj: var T): Buf =
  mkBuf(addr(obj), sizeof(T))

proc pos*(self: Buf): int =
  self.pos

proc initPos*(self: Buf) =
  self.pos = 0

proc dropUnused*(self: Buf) =
  self.size = self.pos

# Returns current pos as a pointer
proc asPtr*(self: Buf): pointer =
  var n = cast[ByteAddress](self.p)
  cast[pointer](n + self.pos)

proc asBuf*(self: Buf): Buf =
  Buf (
    p: self.asPtr,
    size: self.size - self.pos,
    pos: 0,
  )

proc advance*(self: Buf, n) =
  self.pos += n

proc retard*(self: Buf, n) =
  self.pos -= n

proc len*(self: Buf): int =
  self.size

proc write*[T](self: Buf, obj: T) =
  let sz = sizeof(T)
  var v = obj
  let src = cast[pointer](addr(v))
  echo repr(src)
  copyMem(self.asPtr, src, sz)

proc read*[T](self: Buf): T =
  cast[ptr T](self.asPtr)[]

# Read out T struct from the buffer
# and advance the cursor
proc pop*[T](self: Buf): T =
  let v = read[T](self)
  self.advance(sizeof(T))
  v

proc append*[T](self: Buf, o: T) =
  write[T](self, o)
  self.advance(sizeof(T))

when isMainModule:
  var b = mkBuf 101 
  echo repr(b)
  b.advance 10 
  b.retard 3
  echo repr(b)
  echo b.len
  echo b.pos
  echo repr(b.asPtr)

  # can't be
  # let v = b.read[uint64]() or
  # let v: uint64 = b.read
  let v = read[uint64](b)
  echo v
  
  write[uint32](b, 3)
  echo read[uint32](b)

  echo pop[uint32](b)

  var s = "akiradeveloper"
  echo sizeof(string)
  echo sizeof(s)
  echo cast[uint64](addr(s))
  echo len(s)
