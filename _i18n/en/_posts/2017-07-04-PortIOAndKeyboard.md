---
layout: post
title:  Port IO memory and Input input process PS/2 Keyboard IO.
date:   2017-07-04 22:00:20        
categories: development
languages:
- english
- korean
tags:
- 0SOS
- OS
- Operating System
- System
- Paging
- Input
- Keyboard
- 64bit
---        

This is a result until today from yesterday thinking a lot.

![Keyboard Input](/uploads/2017-07-04/OS/Keyboard.png)

The red text was input text.

Now, 0SOS support keyboard input.

Of course, it isn't a shell, it is just a keyboard driver.

It just simply works that input data to video memory.

I'm a little bit worried about it is designed for PS/2 interface. (Old computer's port)

Well, I don't wanna develop exactly the same as the book.

But...

I tried to google it, even I tried to ask the author:


![저자1](/uploads/2017-07-04/OS/writer1.png)


![저자2](/uploads/2017-07-04/OS/writer2.png)


He said like that.

He said you need to control the PCI.

So I defer about that, and I'll design to extentionable.

From the book, It uses input data to queue buffer, I think the queue will be used to the interface.

Well, this problem also defers when I need to develop USB Driver and PCI control.

First, Let's develop the Keyboard Driver on the PS/2 version.

Fortunately, the Laptop keyboard was PS/2 internally.

This is no problem to develop.

It needs a classification of the source codes, because this will begin in earnest.

So I made Driver directory in Source folder.


My method for this is [Port-Map IO](https://ko.wikipedia.org/wiki/%EC%9E%85%EC%B6%9C%EB%A0%A5_%EB%A7%B5_%EC%9E%85%EC%B6%9C%EB%A0%A5), So I separate between PortIO and keyboard.

So Below image was the tree that was made from that directories

![DirectoryTree](/uploads/2017-07-04/OS/DirectoryTree.png)


*I don't know why gch file is added, dammit Google said it was made from gcc when it running with the header file. I don't know how can fix. I think I should take time for checking makefile.

Fist, I hate the '../../' when 'include' so I add the gcc include path option at source directory.  

```
gcc -I ../Source
```

Okay now,

```c
#include "../../Types.h" //We can use below line instead of this line.
#include <Types.h>
```

Well, I tried to make better than before...

Now Let's build time.

Build failure. LoL.

```
undefined reference to PS2~~
```

It makes a message above. 

As I check that message more carefully, that would compile header, and not compile the source file.

Maybe the reason is that in the book was described by a single path.

Okay, Now I start the editing makefile.

I think I spent 3 hours for that.

Below code is 02_Kernel64/makefile.

```make

CSOURCEFILES = $(wildcard ../$(SOURCEDIR)/*.c)
ASSEMBLYSOURCEFILES = $(wildcard ../$(SOURCEDIR)/*.asm)
```
I changed C and assembly code assignment expression above codes to below codes.

```make
CSOURCEFILES = $(shell find ../$(SOURCEDIR)/ -name *.c)
ASSEMBLYSOURCEFILES = $(shell find ../$(SOURCEDIR)/ -name *.asm)
```

It has made a target all about C file, but It wouldn't compile properly.

So It cannot link on ld command at linking step because the file was lost. 

Thus I changed the rule of making o file.

```make
%.o: ../$(SOURCEDIR)/%.c         
    $(GCC64) -c $<         
%.o: ../$(SOURCEDIR)%.asm
    $(NASM64) -c $@ $<
```
Above codes to below codes.

```make
$(COBJECTFILES): $(CSOURCEFILES)
    $(GCC64) -c $^
$(ASSEMBLYOBJECTFILES): $(ASSEMBLYSOURCEFILES)
    $(NASM64) -o $@ $<
```

After building all of the files, that result file would be transfer in Obj directory.

And linker was executed, the disk was completely baked.




![BuildComplate](/uploads/2017-07-04/OS/BuildComplate.png)

I almost cry -_-.

Anyway, 

The build was complete, launch the qemu with happy.

Keep blinking -_-;;;; I try to find why it is working like it.

I wanna use GDB, but... I can't handle it. Also QEMU host the server, so It cannot work step by step.

I'll try to find a GUI version.

Anyway, I found the reason.

Two of the functions in PortIO assembly and header connected oppositely.

Thus they return not properly, also parameter not work properly, the stack was exploded.

PortIO function now available and I start to write keyboard driver using PS/2 Keyboard port.

[I think keyboard driver codes quite a bit long, so you can check here](https://github.com/DevSDK/0SOS/tree/master/02_Kernel64/Source/Driver/Keyboard)

When the user presses the keyboard, they send the scan code.

I make a g_KeyboardStatus structure for using shift and caps lock functions, I implement that when it press that keys, that value would be updated.

```c
//Keyboard.h
typedef struct _KeyboardSataus
{
    BOOL isShiftKeyDown;
    BOOL isCapsLockOn;
    BOOL isNumLockOn;
    BOOL isScrollLockOn;

    BOOL isExtendCode;
    int  SkipPauseCount;

} KeyboardStatus;



static KeyboardStatus    g_KeyboardStatus= { 0,};


```

And I create scan code-askii code map.

I made it can possible separate between combined-key and normal-key.

```c
//Keyboard.h
typedef struct _StructKeyMapEntry
{
    BYTE     NormalCode;
    BYTE     CombinedCode;

} KeyMapEntry;


static KeyMapEntry         g_KeyMapScanTable[KEYMAP_TABLE_SIZE] = {
    { KEY_NONE                ,        KEY_NONE        }, //    0
    { KEY_ESC                 ,        KEY_ESC            }, //    1
    { '1'                    ,         '!'                }, //    2
    { '2'                    ,        '@'                }, //    3
    { '3'                    ,        '#'                }, //    4
    { '4'                    ,        '$'                }, //    5
    { '5'                    ,        '%'                }, //    6
    { '6'                    ,        '^'                }, //    7
    { '7'                    ,        '&'                }, //    8
    { '8'                    ,        '*'                }, //    9
    { '9'                    ,        '('                }, //    10
    { '0'                    ,        ')'                }, //    11
    { '-'                    ,        '_'                }, //    12
    // 나머지는 생략 89개다.

```

Anyway, We can process keyboard input through the table.

You can find Internal Implement on github. 

So you can use on kernel entry like that:

```c
//__Kernel_Entry.c
void __KERNEL_ENTRY()
{

    PrintVideoMemory(5,12, 0x0F,"64 bit C Language Kernel.");    
    BYTE flags;
    int i = 14;
    char temps[2] = {0,};

    if(PS2ActivationKeyboard() == FALSE)
    {
        PrintVideoMemory(5,15, 0x0F,"Keyboard Error    .");    
        while(1);
    }
        
        
    while(1)
    {
            if(PS2CheckOutputBufferNotEmpty() == TRUE)
        {

                BYTE temp = PS2GetKeyboardScanCode();
                if(ConvertScancodeToASCII( temp, &temps[0], &flags) == TRUE)
                    if(flags & KEY_DOWN )
                        PrintVideoMemory(i++, 15, 0x0C, temps);
                
            
        }


            
    }
        
}

```

As you can see, if the input value exists, that would take that value and change to ASCII, and checking whether that is keyboard input.

Not use interrupt yet.

I'm so happy because it works properly.

Finally, I will.. make... Shell..

Anyway, the next thing was inttrupt... It should be hard.


[Full Source Code of Kernel64](https://github.com/DevSDK/0SOS/tree/master/02_Kernel64)
