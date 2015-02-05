# **************************************
#         Nim binding for FUSE
#        (C) 2015 Akira Hayakawa
# **************************************

type Buf* = ref object
  data: seq[char]
  size*: int
  pos*: int

proc mkBuf*(size: int): Buf =
  var data = newSeq[char](size)
  Buf(
    data: data,
    size: size,
    pos: 0,
  )

proc asPtr*(self: Buf): pointer =
  addr(self.data[self.pos])

proc asBuf*(self: Buf): Buf =
  Buf (
    data: self.data[self.pos..self.size-1],
    size: self.size - self.pos,
    pos: 0,
  )

# Parse a null-terminated string in the buffer  
proc parseStr*(self: Buf): string =
  $cstring(addr(self.data[0]))

proc write*(self: Buf, p: pointer, size: int) =
  copyMem(self.asPtr, p, size)

proc write*[T](self: Buf, obj: T) =
  let sz = sizeof(T)
  var v = obj
  self.write(addr(v), sizeof(T))

proc mkBuf*[T](o: T): Buf =
  let b = mkBuf(sizeof(T))
  write[T](b, o)

proc nullTerm*(s: string): string =
  var ss = s
  ss.safeAdd(chr(0))
  ss

proc writeStr*(self: Buf, s: string) =
  var vs = s
  self.write(addr(vs[0]), len(s))

proc mkBufS*(s: string): Buf =
  result = mkBuf(len(s))
  result.writeStr(s)

proc read*[T](self: Buf): T =
  cast[ptr T](self.asPtr)[]

proc pop*[T](self: Buf): T =
  result = read[T](self)
  self.pos += sizeof(T)
