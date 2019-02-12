---
layout: post
title: About Custom Allocator in Comet Engine    
date:   2017-06-25 21:12:20        
categories: development
comments: true
languages:
- english
- korean
tags:
- CometEngine
- GameEngine
- Memory
- Optimization
---        

For the last two weeks, I've been thinking that should implement a custom allocator. 

As you know, if you use a system allocator, you have to use Malloc in C and New in C++.

The problem is the speed. The current method is far too slow for me when I want to use a fast system for the MS unit. 

First of all, I can't ignore the cost of the User-Kernel Mode Context Switch when allocating memory. There's also an additional code that makes it slow. 

I've been mulling over the question "When do I need a really fast code requirement or fastest allocator?" 

As you can see, One of the solutions is to remove the allocator in the code.

Like a making all thing by the stack.

But I hate that.

A bit unexpectedly, I read some documents and found some interesting stuff about the allocator structure.


Pool based memory allocators, Stack-based memory allocators, and Paging addresses with segmentation like OS are candidates for allocators, but they create some problems like free and continuous memory blocks. And It's so complicated.


 Then, I found a FreeList Based Allocator document.
        
![FreeList](/uploads/2017-06-25/CometEngine/Allocator/FreeList.gif)
 
Above is the visualization of the Free List Structure.

A simple summary of the above:

After creating a Linked List in the memory's free space, we slice and provide memory in that list when we try to allocate memory.

When we do Free, make sure to attach that list. (Of course say specifically, it is adjacent. We can make some process like growing the previous block)  

Internally:

While allocating the memory, we implant the 16-byte size Header in that allocated block and provide that block memory's address after 16 bytes to users.  

In other word, Real Allocating size = Request size + Header Size + Align Offset.

After that, we can simply do Free by reading the header information.


When we do Free that Memory block was contained Header, we make to FreeList-Node and link to Free List.

Simple.

Anyway, I've been implementing that stuff in my own Engine

![Allocator](/uploads/2017-06-25/CometEngine/Allocator/CustomAllocation.PNG)


If you want to see the source code for that [LINK](https://devsdk.github.io/CometEngine/html/namespace_comet_engine_1_1_core_1_1_memory.html). (FreeListAllocator Class)

How to use it:

```cpp 
char* MemoryBlock = new char[1024 * 1024 * 10];
Memory::FreeListAllocator allocator = Memory::FreeListAllocator(MemoryBlock, 4, 1024 * 1024);

```

Assign the memory block for Allocator.

And Initialize FreeListAllocator.

```cpp
allocator.alloc(size_t);
allocator.dealloc(void*);
```

Each function is used to memory allocating and free.

Well, as you can see from the image above, it is well-worked.

Also, keep that alignment.

Because I implemented that, Let's prove it is faster than System allocator.

I believe that it is faster than the system stuff so, I made a test.
![Performance](/uploads/2017-06-25/CometEngine/Allocator/PerformanceTest.jpg)

Test condition:

Allocate 10000 times int type array size 1000  

( sizeof(int)*1000) iteration 10000 time. )

The result is

10 times faster than before.

| System Alloc | Custom Alloc | System Free | Custom Free |
|------------|------------|-----------|-----------|
|   0.0120 s |  0.0015 s  | 0.0091 s  | 0.0013 s  |


Well, I appreciate this code. Good. That is fast. 


Later, I think it would be good to attach a Proxy and include a profiler or Leak Management system.
