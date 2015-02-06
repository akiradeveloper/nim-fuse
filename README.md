# nim-fuse

A FUSE Binding for Nim

### Design based on Rust-fuse

The design of this binding is based on rust-fuse.

### Why Nim?

Nim is high-performance but even safer than C.
That's all. Everyone loves speed.

### Todo

* Make a filesystem just backed by an other mountpoint
  (usage: backedfs ./mntA ./mntB) that only sends request 
  to the backing fs. Testing on the filesystem can test 
  this library with high coverage.  
* I need Option type in the stdlib so that I remove
  handmaded one from this library.  
* Add this to nimble database.  
* Send this to upstream stdlib so people can reach
  more easily.  

### Author

Akira Hayakawa

This is my first nim project.
I think there are lot of things remained to improve.
Feel free to comment or send pull request.
