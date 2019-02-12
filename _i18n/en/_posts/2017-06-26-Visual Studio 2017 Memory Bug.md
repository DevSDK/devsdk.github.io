---
layout: post
title: Memory bug on the Visual Studio 2017    
date:   2017-06-26 10:41:20        
categories: development
languages:
- english
- korean
tags:
- VisualStudio
- Memory
- Bug
---        




[Addition]

It wasn't a debugger issue.

I guess this is the visual studio's problem.

I found the same issue without debugging.

First of all, this is just my supposition, so, it's possible that this isn't VS's problem.  

I think this is made by one of the VS's so many processors.

In the case that is a VS problem, I can't do anything, so I'm not sure I can even research what the problem is, but I noticed when VS  was closed then the memory usage return to normal. 
Because of that, I guess I'll have to solve the issue by researching some of the cases that cause processors to by killed when closing VS

------

I experienced this stuff a while ago.

I noticed this happened on Visual Studio 2017 first.

On 2010, 2013 and 2015, I didn't experience this.... or I maybe I used, it after 2015 on a laptop?

anyways,

I wasn't sure when it happened.

When the environment was Laptop:

I didn't know why, but this time when I closed my laptop while running C# WPF solution Debug mode and without running C++ solution, I got a lot of lag because they use all of the memory.   


It was impossible out of the memory on my laptop if that was a normal program. 

Anyways, I felt delay and I wanted to know what happened so I open task manager.

I got a shock.

![Memory](/uploads/2017-06-26/VisualStudio/VisualStudioMemory.png)

It takes 31GB memory.

I guess one of the Visual Studio processors is going to explode. 

I didn't know why. I couldn't act in that situation.

It made me confused.


