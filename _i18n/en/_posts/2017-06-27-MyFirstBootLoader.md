---
layout: post
title: The first 0SOS's BootLoader.
date:   2017-06-27 10:20:27        
categories: development
languages:
- english
- korean
tags:
- 0SOS
- OS
- Operating System
- System
- Booting
- function
---        


Something learning gives me pleasure.

Of course, If you want to memorize something effectively, you should have a hard time learning. So I'm trying to avoid copy example code from the book. 


I tried to change variable name, order and rewrite to a function.

Well, It's so fun while I tried to do something and got trouble. 

As you know, It needs much time than before. 


In this time, It can be called a bootloader.

Of course, This bootloader aimed to the floppy disk, but later, It can be changed hard disk.

I decided to satisfy for now because I'm a learner.

When I execute the bootloader:

![BootLoader](/uploads/2017-06-27/OS/BootLoaderRun.png)


It's worked! You can see the number 1234567 in the image because I need to detect this bootloader has errors. So I wrote this code for jumping to loaded memory.


(I'm already set up an increasing number on loaded memory (also it can't be upper than 10 because that is ASCII value.))

The count of the number is exactly 1024.

That is the count of a loaded sector.

Anyway, The steps of bootloader are the following: 

Initialize register(Stack, Adress, ...) on the start point. 

After then execute the message print function. The calling conversion is cdecl on the C Language.

Because of the caller clean up the stack. Anyway, it isn't point. No problem when it changed stdcall.

For BIOS services, We need to call interrupt.

When it makes some errors, it would be handled by an error handler. 

If not, Complete.

And then jump to the loaded memory.

Code


```nasm
[ORG 0x00]
[BITS 16]

SECTION .text

jmp 0x07C0:START

;;;;;;;;;;;;;;;;;
;;;; CONFIG ;;;;;
;;;;;;;;;;;;;;;;;

TOTALSECTOR: dw 1024 ;



START:
    mov ax, 0x07C0
    mov ds, ax


    ;;;;;;;;;; STACK INITALIZATION ;;;;;;;;;;
    mov ax, 0x0000
    mov ss, ax
    mov sp, 0xFFFE
    mov bp, 0XFFFE

    mov si, 0

    call CLEAR 


    ;;;;;;;;;; PRINT HELLO ;;;;;;;
    push HELLO
    push 0
    push 0
    call PRINT
    add sp, 6
    ;;;;;;;;;; PRINT LOAD INFO ;;;;;;
    push LOADINFO
    push 0
    push 1
    call PRINT
    add sp, 6


    
DISKRESET:
    mov ax, 0
    mov dl, 0
    int 0x13
    jc ERRORHANDLER

    ;;;;;;;;;;; READ DISK SECTOR ;;;;;;;
    mov si, 0x1000
    mov es, si
    mov bx, 0x0000

    mov di, word[TOTALSECTOR]

.READ:
    cmp di, 0
    je BREAKREAD
    sub di, 0x1

    mov ah, 0x02
    mov al, 0x1
    mov ch, byte[TRACK]
    mov cl, byte[SECTOR]
    mov dh, byte[HEADER]
    mov dl, 0x00
    int 0x13
    jc ERRORHANDLER

    ;;;;;;;;;; calculate Address
    add si, 0x0020

    mov es, si

    mov al, byte[SECTOR]
    add al, 0x01
    mov byte[SECTOR],al
    cmp al, 19
    jl .READ

    xor byte[HEADER], 0x01
    mov byte[SECTOR], 0x01

    cmp byte[HEADER], 0x00
    jne .READ
    add byte[TRACK], 0x01    
    jmp .READ
BREAKREAD:
    push LOADSUCCESS
    push 24
    push 1
    call PRINT
    add sp,6

    jmp 0x1000:0x0000

ERRORHANDLER:
    push DISKERROR
    push 24
    push 1
    call PRINT
    jmp $

PRINT:
    push bp,
    mov bp, sp
    
    push es
    push si
    push di
    push ax
    push cx
    push dx    

    mov ax, 0xB800
    mov es, ax


    mov ax, word[bp + 4]
    mov si, 160
    mul si
    mov di, ax

    mov ax, word[bp + 6]
    mov si, 2
    mul si
    add di, ax

    mov si, word[bp+8]
.PRINTLOOP
    mov cl, byte[si]

    cmp cl,0
    je .ENDPRINTLOOP

    mov byte[es:di], cl

    add si, 1
    add di, 2
    jmp .PRINTLOOP

.ENDPRINTLOOP
    pop dx
    pop cx
    pop ax
    pop di
    pop si
    pop es
    pop bp
    ret


CLEAR:
    push bp
    mov bp, sp
    
    push es
    push si
    push di
    push ax
    push cx
    push dx

    mov ax, 0xB800
    mov es, ax
    
.CLEARLOOP:
    mov byte[es:si],0
    mov byte[es:si+1], 0x0B
    add si,2
    
    cmp si,80*25*2
    jl .CLEARLOOP
    
    pop dx
    pop cx
    pop ax
    pop di
    pop si
    pop es
    pop bp
    ret    



HELLO: db 'Welcome To 0SOS.',0
DISKERROR: db 'ERROR', 0
LOADSUCCESS: db 'SUCCESS',0
LOADINFO: db 'Now Loading From DISK...', 0

SECTOR:    db 0x02
HEADER:    db 0x00
TRACK:    db 0x00






times 510 - ($ - $$) db 0x00

db 0x55
db 0xAA

```

It worked correctly. 


Now, It time to take 32-bit mode. 


Before that, I should complete another working.




