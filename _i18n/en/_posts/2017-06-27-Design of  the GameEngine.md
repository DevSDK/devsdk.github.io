---
layout: post
title: Approximately, I thought an idea for the container of Comet Engine.
date:   2017-06-27 22:52:27        
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

Recently, I'm enjoying developing the OS. Is the reason fresh?

So I think this project will be freeze...

I mean, It is not completely frozen. I'll make it very slowly.

I can take it after a few weeks rest. 

Um, I  a few weeks too much. Hum.. a few days? I guess?

Today, I decided to focus on the Game Engine.

First of all, I fixed warnings in Custom Memory on Visual Studio. 

When I change c style casting to static_cast, that error has been removed.

Anyway, I should make the library that wasn't tiny, called Container.

So, I drew UML instead of the code.

Reference is Java's Container and C#'s Collection. 

Also, I referred to C++'s STL.


![This sturcture](/uploads/2017-06-27/CometEngine/UML.png)

It wasn't' had detail like the name of the functions and member. It just had a silhouette...

After that, I should consider this with paper writing.

I'll add patterns like Iterator later.

Anyway, I make a Custom Allocator, so why don't I develop the Container.

Well, Because custom allocator has a limitation of the memory size (They require the Memory blocks), I should implement the wrapper for the resizable memory structure.

Haa, I guess I'll get a headache even I just concern about it.

As you know, the Array List is easy for that but Linked List is......

Roughly, I should write abstraction for memory require code.  

I'm not sure how can I solve when the memory pointer address is changed.

One of the solution:

On the user-side must not access in data address.

Well, I'm not implementing the foundation of this system yet.

Also, something that I should concern is how can I guarantee thread-safe between containers.

I think I should get gray hair.....

I need to draw a simple design of functions and requirements,

or not immediately...

If I read and examine STL's internal source code, it'll give some inspiration I guess, but I don't want to do like that because they had a lot of damm template.

The aim is faster than STL.

I felt some depression when I thought that I should touch my game engine project sometimes

Also, I want to develop the OS at the same time...

I need more time to split.

