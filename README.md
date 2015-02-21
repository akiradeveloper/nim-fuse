# nim-fuse

A FUSE Binding for Nim

[![Build Status](https://travis-ci.org/akiradeveloper/nim-fuse.svg)](https://travis-ci.org/akiradeveloper/nim-fuse)

The aim of nim-fuse is to provide the fast, safe and portable
fuse implementation and to show a real-world application of Nim language.

![Architecture](https://rawgit.com/akiradeveloper/nim-fuse/master/arch.svg)

### Browse API

https://rawgit.com/akiradeveloper/nim-fuse/master/fuse.html

### Why Nim?

* Nim is high-performance but much safer than C.
Now you don't have a reason to write your filesystem in C fuse.  
* nim-fuse isn't just a rewrite of C fuse but a real improvement
with the cutting edge features that Nim provides (e.g. concurrency)  

### Todo

* Implement in-memory filesystem for testing FuseFs (low-level interface)  
* Port fusexmp.c for testing HiFuseFs (high-level interface)  
 
### Author

Akira Hayakawa (ruby.wktk@gmail.com)
