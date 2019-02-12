---
layout: post
title: Now 0SOS will be written by C Langauge.
date:   2017-06-29 00:51:20        
categories: development
languages:
- english
- korean
tags:
- 0SO
- OS
- ProtectedMode
- Operating System
- System
- 32bit
- Booting
- C Language
---        

I guess this post is quite long.

Phew, I've spent a good day because I focus on OS today.

Everything is fresh!

Afternoon today, I've succeeded 0SOS jumping to 32bit code.

Well, It has been spent many steps for that.

Like, organize GDTR and GDT.


You can see that [here](https://devsdk.github.io/development/2017/06/28/Hello32BIt.html)

Now, We could write C Langauge kernel source code.


![Yes!](/uploads/2017-06-29/OS/Finaly.png)

A single line, Mostly I have an effort. 

Above running C code is:

```c

#include "Types.h"


void PrintVideoMemory(int x, int y, const char* _str);


void __Kernel__Entry()
{

    PrintVideoMemory(0,3, "Now C Language Binary.");
    
    while(1);
}

void PrintVideoMemory(int x, int y, const char* _str)
{
    CHARACTER_MEMORY* Address = ( CHARACTER_MEMORY* ) 0xB8000;
    
    int i = 0;
    
    += ( y * 80 ) + x;

    for ( i = 0; _str[i] != 0; i++)
    {
        Address[i].bCharactor = _str[i];
    }


}

```

As you can see, It is working as well!

Again, I need many stuff for preparing and a waste of time.

First, We need controlling linker, build script of the code and jumping asm entry point to C language. 

Basically, We can use the 32-bit code so we can use the result of the compiler.

Of course, We cannot use the output of the default setup. Because they had a lot of unnecessary data for Operating System kernel, Like code position and reorder formation.

Sometimes they attach the library, even they try to link.

And that is different from the section information. 

So we need to edit link script.

Of course, I didn't have expertise of link script.

And the author said If He explains that, it would be a book.

So I just try to copy about that.

I can understand about a little bit, of course not at all. But I can see a big picture.

I'll not copy my link script on here. That wasn't point. 

If you want to see that, [here](https://github.com/DevSDK/0SOS/blob/master/LinkerScript.x)

It really hard about explains all of them. Foundation of code is from /usr/lib/ldscript/elf_i386.x


I copied the code from there and then remove unnecessary code, changing sections and addressing. 

The most important thing is:


```Logos
    /*SKIP*/
  
  .text 0x10200      :
  {
    *(.text.unlikely .text.*_unlikely .text.unlikely.*)
    *(.text.exit .text.exit.*)
    *(.text.startup .text.startup.*)
    *(.text.hot .text.hot.*)
    *(.text .stub .text.* .gnu.linkonce.t.*)
    /* .gnu.warning sections are handled specially by elf32.em.  */
    *(.gnu.warning)
  }

    /* SKIP */


  .data           : 
  {
    *(.data .data.* .gnu.linkonce.d.*)
    SORT(CONSTRUCTORS)
  }
      /* SKIP */

}

```

First, I edited almost half the code.

Let's see this.

As you can see, We were addressing 0x10200 at the start point of .text section and addressing data section after that. 

Then let's compile that C file for the kernel with many options.

```
gcc -c -m32 -ffreestanding Main.c
```

If We compile like that, it would be 32-bit code, not linked and not loaded another library. 

The object file that is produced by compiler link again.

Currently, this file cannot execute. It just the object file.

When this file disassemble:

Plus, The assembly code on that image above is 3 number addition function example for this posting instead of the kernel.



![Looks like this](/uploads/2017-06-29/OS/NotLink.png)

You could see the start address command line is 0

So, We need to use a linker script wrote before.

```
 ld -elf_i386 -nostdlib -T LinkerScript.x Main.o Main.elf
```

Skip of more things after that command line.

So that will make relocation instruction and runnable.

![Figure](/uploads/2017-06-29/OS/Linked.png)

The important thing is not instruction. 

That is different to the start address. 

Anyway, If you made it, the something work left is to initialize 32-bit code and jump kernel entry point to c language entry point.

``` nasm

 
 [BITS 32]
 
 PROTECTEDMODE:
     mov ax, 0x10
     mov ds, ax
     mov es, ax
     mov fs, ax
     mov gs, ax
 
     mov ss, ax
     mov esp, 0XFFFE
     mov ebp, 0XFFFE
 
     push (SWITCHMESSAGE - $$ + 0x10000)
     push 2
     push 0
     call PRINT
     add  esp, 12
 
     jmp dword 0x08:0x10200      ;Let's Jump To C

```

Uh, It's hard to write build script.

I think I need to examine in makefiles.

Anyway, Build completed after one or two hours writing build script with brain burning.

Oh, I'm excited. 

So I look at...

![Explode](/uploads/2017-06-29/OS/VMExplod.png)

It must be like the first picture, but as you can see the VM was exploded.

So I can suppose why the VM was exploded.

Because I have to choose just one section to read.

After editing that, It worked correctly.

So I going to prepare that find why it wasn't worked correctly by reading the dump files.

Huh, It gonna more complicate!

Let's do this to END.