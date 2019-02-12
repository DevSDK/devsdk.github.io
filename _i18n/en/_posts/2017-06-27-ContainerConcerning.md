---
layout: post
title: Thinking about Container Library in Comet Engine
date:   2017-06-27 18:42:27        
categories: development
languages:
- english
- korean
tags:
- CometEngine
- GameEngine
- Container
- Library
- Optimization
---        

I want to develop this game engine slowly and completely. 

So, I'd like to wish this fast and strong

The first step is Custom Allocator providing.

[You can see about that](https://devsdk.github.io/development/2017/06/25/Custom-Allocator.html)

Anyway, I hope to construct step by step from the low-level subsystem to the editor. Well, I didn't have a deadline. 

(Maybe 2 years?)

The second step is container designing and implements for providing a container library.

I should make this twice version:

Custom Allocator version and System Allocator version.

It'll be faster than STL. Of course, In case the same algorithm.

Also, It's more comfortable for maintaining.

Now concerning thing is: 

What is the best prefix for the Custom Allocator version?

One of the prefixes is C. 

```cpp
    CArrayList<int>
```

Well, I'm not sure it is the perfect prefix, but it is exactly matched with Game Engine's name.

On the other hand, The System Allocator version will not take any prefix. 

Maybe, the System allocator will use Virtual Alloc.

Also, I concern about the namespace. Maybe the candidates are:

```cpp
CometEngine::Core::Container::C //Custom Allocator
CometEngine::Core::Container::S //System Allocator
```
or without S and C in the namespace.

I should hard work to organize those classes.  

Also, It isn't urgent work, so I should think more slowly.

I have to see STL internal. 




## Addtion

Ah, Damm it, About constructing thread-safe.

That concerning are making more gray hairs.
