---
layout: post
title: How to access memory in Real-Mode    
date:   2017-06-26 20:02:20        
categories: development
comments: true
languages:
- english
- korean
tags:
- 0SOS
- OS
- Operating System
- System
- Memory
---        


I have just wasted 2 hours because I just forget things.

I'm sure I've already read it before but why did I forget? 


I've rattled my brains 2 hours because I saw that 0x020 shows as 512 in the ES register.  

As you can see the value is 32. It definitely wasn't 512.

Don't forget,

in the real-mode, segment registers such as CS, DS, ES, FS, and SS are used for addressing physical memory addresses by multiplying 16 and adding the general register value.


In another word, to ASM.


```nasm
mov si, 0x0020 
mov es, si
```

If you see code like this, you can just imagine that 0 is added onto the end figure.

It's is obviously basic stuff even I read before but forgot.

 