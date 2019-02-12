---
layout: post
title: OS DevLog-Let's push into the frame buffer.    
date:   2017-06-26 17:20:20        
categories: development
comments: true
tags:
- 0SOS
- OS
- Operating System
- System
- FrameBuffer
---        

I hadn't been looking for other modes,

and I didn't know anything about the GUI Framebuffer yet so, I wrote this; my area of expertise.

In real-mode, the text video memory address is 0xB800.

A single character takes 2 bytes. The first byte is the ASCII code and the second byte is attribute value.

If you want to see specifics, [here](https://en.wikipedia.org/wiki/VGA-compatible_text_mode)

In case you've written a bootloader or something, we can display the characters on the screen when we push an order into 0xB800  like 'H', (attribute), 'E', (attribute)...  

We definitely couldn't see clearly without initialization.

We need to clear in the existing (QEMU) BIOS's data.

In order to do the above, we need to clear the frame buffer. (setting 0)

When clearing, insert the attribute in the framebuffer.

```nasm

[ORG 0x00]              ; Start Address 0x00
[BITS 16]               ; 16 bit codes


SECTION .text           ;text section.

jmp 0x07C0:START        ;Jump to code startpoint.


START:
    mov ax, 0x07C0      ; Bootloader start address (before that containing something stuff.)
    mov ds, ax          ; assign data segment address
    mov ax, 0xB800      ; assign video memory address
    mov es, ax
    mov si, 0           ; register for string indexing
    
.SCREENCLEARLOOP        ; Label for screen clear
    mov byte[ es: si],0 ; Interation from 0xB800 by size

    mov byte[ es: si + 1], 0x0A

    add si,2
    cmp si, 80*25*2     ; If *si* is smaller than 80*25*2 (size of video memory), run codes below.
    jl .SCREENCLEARLOOP ; Iteration

    mov si, 0           ;Initialization
    mov di, 0

.MESSAGELOOP:           ; Label of displaying message on screen
    mov cl, byte[MESSAGE1+si]   ;It's like array[i] in C Language. Checking Message1
    cmp cl, 0                   ;If this meet 0,
    je .MESSAGEEND              ; exit

    mov byte[es:di],cl
    
    add si, 1                   ;Index for character
    add di, 2                   ;Index for video memory

    jmp .MESSAGELOOP

.MESSAGEEND
    jmp $

MESSAGE1:   db 'Hello World. Boot Loader Start', 0 


times 510 - ($-$$) db 0x00

db 0x55
db 0xAA



```


I added the comment.

Well,

![HELLO](/uploads/2017-06-26/OS/HelloWorld.png)

It worked clearly.

As you can see, it isn't a bootloader. 

It is just binary for displaying characters on the framebuffer

If you say "What is different about printing 'Hello world!' in C?", Just close this posting.



