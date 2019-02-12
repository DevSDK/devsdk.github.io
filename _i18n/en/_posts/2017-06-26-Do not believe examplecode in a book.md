---
layout: post
title: When you read a book and find something odd check if it was a misprint
date:   2017-06-26 22:52:20        
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
- function
---        

When I read OS book descriptions, I focus on example code within my expertise

On page 149, Function Call.

The issue was, just one variable was contained in the function on the stack frame, but the stack pointer was decreased by 8byte.

After that page was something weird.

I've tried to find whether it was a misprint or not in the online community.

The author said, he pasted Visual Studio's code into the book.

Obviously, VS caused a weird result.
Anyways, The code that took up my time was:

```c
    int Add(int a, int b, int c)
    {
        return a+b+c;
    }
    void main()
    {
        int Result;
        Result = Add(1,2,3);
    }

```

I knew that void main wasn't standard.  That part was written in the book.

The code above to assembly:

```nasm
Add:
    push ebp
    mov ebp, esp
    
    mov eax, dword[ebp + 8]

    add eax, dword[ebp + 12]
    add eax, dword[ebp + 16]

    pop ebp
    
    ret 12

main:
    push ebp
    mov evp, esp

    sub esp, 8

    push 3
    push 2
    push 1
    call Add
    mov dword[ebp - 4],eax
    ret
```

It would be changed like this above. The problem was three lines below from the main function and two lines above from last:


```nasm
sub esp, 8


mov dword[ebp - 4], eax
```

I wondered what the hell was going one with the 4 bytes from the stack frame.

I didn't know whether there was an internal requirement or whether it was.

Anyways, that had just one variable in C code definitely. 

So I didn't know why need 8 bytes.

When I studied Compiler, I learned the memory assigned in stack per variable size. So it was something weird.

It is different when I develop the OS?

I'm not thinking like that so, I tried to find inserting something into stackframe but it wasn't

After then, I ask author and author said, I wrote this code by VS's assembly code. 

Anyways, Maybe the correct code is: 

```nasm
sub esp, 4


mov dword[ebp], eax
```

[Author said that is correct](http://jsandroidapp.cafe24.com/xe/6311#comment_6377)

