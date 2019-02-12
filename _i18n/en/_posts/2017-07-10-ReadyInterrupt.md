---
layout: post
title: Changing GDT & Defining GDT & Setting TSS    
date:   2017-07-10 11:40:20        
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
- Paging
- Interrupt
- 64bit
---        

Until now, sometimes I've got something to work, and I spent a lot of debugging time at this time.

so I write this now.

Well....

Until now, 0SOS didn't have an interrupt process code.

So If the interrupt occurs, it makes system down or processed by the default handler 

Anyway, I don't like it.

For input keyboard or some interrupt application, I've made IDT for prepare interrupt process.

![the result](/uploads/2017-07-10/OS/InterruptShow.png)

Still, they connected the dummy handler, but interrupt has occurred, the handler was executed for process interrupt. 

I defined the IST data structure for handling interrupt on the 7~8MB area.

And I assign IST using TSS segment, and I connect about hundred of dummy handler and dummy descriptor in IST.

Below image was memory map.

![tiresome](/uploads/2017-07-10/OS/MemoryMap.png)

I'll draw paint next time. Too much effort.

Anyway, The point is setting up TSS selector in GDT, defining TSS and constructing IDT.

Well, It looks simple.

Let's see the codes.

And I'll write a debugging log.

First, Dummy handler:

```c
void DummyHandler()
{
    Pt(0,0,0x0F ,"===============================");
    Pt(0,1,0x0F ,"===============================");
    Pt(0,2,0x0F ,"===    Test Interrupt Hander===");
    Pt(0,3,0x0F ,"===============================");
    Pt(0,4,0x0F ,"===============================");
    
    while(1);   //Busy waiting for no retuning.
}
```

If some interrupt has occurred, it would be handled by that function.

In other words, if you try to divide 0, it would occur interrupt. So That function was executed. 

You can see the result in the first image.

Anyway, I need to re-define GDT, TSS using IST and make IDT for process interrupt.

So I make a Descriptor directory and define some files for that.


![File tree](/uploads/2017-07-10/OS/DirectoryTree.png)

Descriptor.asm and Descriptor.h handle asm code for GDTR, IDTR and TSS load to the processor. 

IDT.c and IDT.h are related at IDT

and GDT.c and GDT.h are related at GDT.

If you wanna look detail GDT.h, please check the below URL.

[GDT.h URL](https://github.com/DevSDK/0SOS/blob/master/02_Kernel64/Source/Descriptor/GDT.h)

I define the bundle of codes that would be used often.

The implementation was:

```c
//GDT.c

#include "GDT.h"
#include "IDT.h"
#include <Utility/Memory.h>

void InitializeGDTWithTSS()
{
    GDTR* _gdtr = (GDTR*)GDTR_POINTER;

    GDT_ENTRY8* _gdt_entry      = (GDT_ENTRY8*)(GDTR_POINTER + sizeof(GDTR)); 
    TSS_SEGMENT* _tss_segment    = (TSS_SEGMENT*)((QWORD)_gdt_entry+GDT_TABLE_SIZE);    
    _gdtr->Size         = GDT_TABLE_SIZE - 1;
    _gdtr->BaseAddress  = (QWORD)_gdt_entry;

    SetGDT_Entry8((&_gdt_entry[0]), 0, 0, 0, 0, 0);
    SetGDT_Entry8((&_gdt_entry[1]),0,0xFFFFF, GDT_ENTRY_HIGH_CODE, GDT_ENTRY_LOW_KERNEL_CODE, GDT_TYPE_CODE);
    SetGDT_Entry8((&_gdt_entry[2]),0,0xFFFFF, GDT_ENTRY_HIGH_DATA, GDT_ENTRY_LOW_KERNEL_DATA, GDT_TYPE_DATA);
    
    SetGDT_Entry16(((GDT_ENTRY16*)(&_gdt_entry[3])), (QWORD)_tss_segment, sizeof(TSS_SEGMENT)-1, GDT_ENTRY_HIGH_TSS,
                    GDT_ENTRY_LOW_TSS, GDT_TYPE_TSS);

    InitializeTSSSegment(_tss_segment);
    
}
void SetGDT_Entry8(GDT_ENTRY8* _entry, DWORD _BaseAddress,
                     DWORD _Size, BYTE _HighFlags, BYTE _LowFlags, BYTE _Type)
{
    _entry->Low_Size            =   _Size & 0xFFFF;
    _entry->Low_BaseAddress     = _BaseAddress & 0xFFFF;
    _entry->Low_BaseAddress1    = ( _BaseAddress >> 16 ) & 0xFF;
    _entry->Low_Flags           = _LowFlags | _Type;
    _entry->High_FlagsAndSize   = ((_Size>>16) & 0xFF) | _HighFlags;
    _entry->High_BaseAddress    = (_BaseAddress>>24) & 0xFF;
}

void SetGDT_Entry16(GDT_ENTRY16* _entry, QWORD _BaseAddress,
                     DWORD _Size, BYTE _HighFlags, BYTE _LowFlags, BYTE _Type)
{
    _entry->Low_Size            = _Size & 0xFFFF;
    _entry->Low_BaseAddress     = _BaseAddress & 0xFFFF;
    _entry->Mid_BaseAddress     = (_BaseAddress >> 16 ) & 0xFF;
    _entry->Low_Flags           = _LowFlags | _Type;
    _entry->High_FlagsAndSize   = ((_Size >> 16) & 0xFF) | _HighFlags;
    _entry->High_BaseAddress    = (_BaseAddress  >> 24) & 0xFF;
    _entry->High_BaseAddress2   = (_BaseAddress>>32);
    _entry->Reserved            = 0;
}

void InitializeTSSSegment(TSS_SEGMENT* _tss)
{
    _MemSet(_tss, 0, sizeof(TSS_SEGMENT));    
    _tss->IST[0] = IST_POINTER + IST_SIZE;
    _tss->IOMapBaseAddress  =  0xFFFF;
}

```

Well, You can see GDT load on memory through InitializeGDTWithTSS function. (You should check GDTR_POINTER. That was completely calculated.)

Not different normal GDT, I suggest you Google it.

Let's check IDT.

```c
//IDT.h

#ifndef __IDT_H__
#define __IDT_H__
#include "GDT.h"

#define IDT_TYPE_INTERRUPT      0x0E    //0b00001110
#define IDT_TYPE_TRAP           0x0F    //0b00001111
#define IDT_ENTRY_DPL0          0x00    //0b00000000
#define IDT_ENTRY_DPL1          0x20    //0b00100000
#define IDT_ENTRY_DPL2          0x40    //0b01000000
#define IDT_ENTRY_DPL3          0x60    //0b01100000
#define IDT_ENTRY_P             0x80    //0b10000000
#define IDT_ENTRY_IST1          1
#define IDT_ENTRY_IST0          0

#define IDT_ENTRY_KERNEL    (IDT_ENTRY_DPL0 | IDT_ENTRY_P)
#define IDT_ENTRY_USER      (IDT_ENTRY_DPL3 | IDT_ENTRY_P)

#define IDT_MAX_ENTRY_COUNT     100
#define IDTR_POINTER            (sizeof(GDTR) + GDTR_POINTER \
                                + GDT_TABLE_SIZE + TSS_SEGMENT_SIZE)
#define IDT_POINTER            (sizeof(IDTR) + IDTR_POINTER)
#define IDT_TABLE_SIZE          (IDT_MAX_ENTRY_COUNT + sizeof(IDT_ENTRY))


#define IST_POINTER         0x700000
#define IST_SIZE            0x100000


#pragma pack(push, 1)

typedef struct _Struct_IDT_Entry
{
    WORD Low_BaseAddress;
    WORD SegmentSelector;

    BYTE IST;
    //3Bit IST, 5Bit set 0
    BYTE FlagsAndType;
    // 4Bit Type, 1 Bit set 0, 2Bit DPL, 1Bit P
    WORD Mid_BaseAddress;
    DWORD High_BaseAddres;
    DWORD Reserved;

}IDT_ENTRY;

#pragma pack(pop)

void InitializeIDTTables();
void SetIDTEntry(IDT_ENTRY* _entry, void* _handler, WORD _Selector, 
                    BYTE _IST, BYTE _Flags, BYTE _Type);


void Pt(int _x, int _y, BYTE _Attribute ,const char* _str);

void DummyHandler();

#endif /* __IDT_H__ */

```

Yet IDT.h file wasn't huge.

You can see as well, I designed that could place on memory by sizeof instead directly use _POINTER that was pointing starting address.

 Below was an implement of IDT.c.

```c
//IDT.c
#include "IDT.h"

void InitializeIDTTables()
{
    IDTR* idtr = (IDTR*) IDTR_POINTER;
    IDT_ENTRY* entry =  (IDT_ENTRY*)(IDTR_POINTER + sizeof(IDTR));
    
    idtr->BaseAddress   = (QWORD)entry;
    idtr->Size          = IDT_TABLE_SIZE - 1;

    for(int i = 0; i < IDT_MAX_ENTRY_COUNT; i++) 
    {
        SetIDTEntry(&entry[i],DummyHandler,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    }

}
void SetIDTEntry(IDT_ENTRY* _entry, void* _handler, WORD _Selector, 
                    BYTE _IST, BYTE _Flags, BYTE _Type)
{
    _entry->Low_BaseAddress =  (QWORD) _handler & 0xFFFF;
    _entry->SegmentSelector = _Selector;
    _entry->IST             = _IST & 0x3;
    _entry->FlagsAndType   = _Flags | _Type;
    _entry->Mid_BaseAddress = ((QWORD)_handler >> 16) & 0xFFFF;
    _entry->High_BaseAddres = ((QWORD)_handler >> 32);
    _entry->Reserved        = 0;
}
//Skip Pt and DummyHandler

```
I skip that dummyhandler and print vide memory function.

IDT was defined and loaded by the above codes.

Descriptor.h and Descriptor.asm work for linking the handler and processor.

```c
//Descriptor.h

#ifndef __DESCRIPTOR_H__
#define __DESCRIPTOR_H__

void LoadGDTR(QWORD _GdtrAddress);
void LoadTR(WORD _TssSegmentOffset);
void LoadIDTR(QWORD _IDTRAddress);

#endif /*__DESCRIPTOR_H__*/

```

Above code linked at the assembly codes. the assembly codes are:

```nasm
;Descriptor.asm

[BITS 64]
                     
global LoadGDTR, LoadTR, LoadIDTR
                        
SECTION .text

LoadGDTR:
    lgdt[rdi]
    ret
LoadTR:
    ltr di
    ret

LoadIDTR:
    lidt[rdi]
    ret

```

It's simple. It's just table notification to table code.

I add the below codes to initialize and link to the processor at the kernel entry. 

And Below code makes a divide by zero interrupt when we press some key.

```c
    //__Kernel_Entry.c
    PrintVideoMemory(5,12, 0x0F,"Initialize GDT........................................");
    InitializeGDTWithTSS();
    LoadGDTR(GDTR_POINTER);
    PrintVideoMemory(60,12,0x0A,"[SUCCESS]");
    PrintVideoMemory(5,13, 0x0F,"Load TSS Segment .....................................");
    LoadTR(GDT_TSS_SEGMENT);
    PrintVideoMemory(60,13,0x0A,"[SUCCESS]");
    PrintVideoMemory(5,14, 0x0F,"Initialize IDT .......................................");
    InitializeIDTTables();
    LoadIDTR(IDTR_POINTER);
    PrintVideoMemory(60,14,0x0A,"[SUCCESS]");
    //...

```

```c
//__Kernel_Entry.c
    if(flags & KEY_DOWN )
    {
        PrintVideoMemory(i++, 15, 0x0C, temps);
        int b = 10 / 0;
    }

```

Thus far, this is an addition in the codes. 

Well.... I should consider about copy&paste whole codes.

I think it has a better way. Like above Kernel Entry. 


Okay, below article is debugging log when I developed above.

I try to build with a happy mind.

```

undefined reference to ....


```

Dammit.


I try to find what is a problem.

I check the linker log, Assembly object file looks weird. 

So I check through the objdmp... OMG, that files exactly same without the filename.

(PortIO.o and Descriptor.o was same PortIO.o data)

nasm looks like gcc but it cannot build several files.

```make
$(ASSEMBLYOBJECTFILES): $(ASSEMBLYSOURCEFILES)
     $(NASM64) -o $@ $<
```

In fact, It can be built by $<. If it is $^, nasm would be stopped because of too many arguments.

So this happen was made by more than two asm file.

gcc could build with option -c and source files, but nasm didn't.


I wanna find the way.

First, I try to use the nasm function. I consider that but it's impossible. Or I didn't know?


Anyway, I solved this problem by inserting foreach in makefile.

```make

$(ASSEMBLYOBJECTFILES):$(ASSEMBLYSOURCEFILES)
$(foreach var,$(ASSEMBLYSOURCEFILES),$(NASM64) $(var) -o $(notdir $(patsubst %.asm, %.o,  $(var))) ;)
```

I waist hours for the above shortcode lines.

![Build success!](/uploads/2017-07-10/OS/BuildDone.png)

Well, I guess I don't need to touch makefile.

I try to run.

It didn't work properly.

I'm mental hurt by makefile. So I'm so confused.

I've spent a rest little bit.



So, we need to check GDT, IDT and TSS data would be loaded properly.

The first we try, Check the GDTR that explicitly assigned memory address. 

![GDTHEX](/uploads/2017-07-10/OS/Hex_GDT.png)


Green is GDTR, red is GDT table.

GDTR's assignment is GDT address appointing.

I designed GDT next to GDTR, So it should refer 0x142010, and i should check that HEX. And it is properly worked.

Let's look at the GDT.

Well, GDTR assignment is properly worked, and I can check the output. So I think GDT table content wasn't wrong.

But, I check harder the TSS segment.

The starting address is 0x142028.

If I make table:

![TSSSelector](/uploads/2017-07-10/OS/Table_TSS.png)

I check the base address because I tried to check the memory part.

Also, I designed a tss table next to GDTR too, it should be 0x142038.

Tss Segment descriptor base address looks no-problem.

![HEX_TSS_ERROR](/uploads/2017-07-10/OS/HEX_TSS_ERROR.png)

I check again. Something wrong.

The last 2byte, I set FFFF on IOMap. Where they go? 

Also IST base address 0x800000 has gone.

I try to check the codes.

OMG.

I write the InitializeTSSSegment function but I wouldn't call it.

So I solve that problem by calling that function.

![HEX_TSS_WORK](/uploads/2017-07-10/OS/Hex_TSS_Work.png)

... 

You can see the different above image and right above image.

It worked properly now.

But it still didn't work.

So I should check the IDT.

Hum...

![HEX_IDT_ERROR?](/uploads/2017-07-10/OS/IDT_Error.png)

Ah...??

It memory calculation wasn't properly worked.

I plan right next to the TSS but why it refer 0x1421A0?

I checked the codes.

```c
IDT_ENTRY* entry =  (IDT_ENTRY*)IDTR_POINTER + sizeof(IDTR);
```

Okay, I mistake Again -_-

Of course, It appoints before if like that. because After casting to the pointer and add.

So I solve this change above code to below code. 


```c
IDT_ENTRY* entry =  (IDT_ENTRY*)(IDTR_POINTER + sizeof(IDTR));
```

Addition, This code wasn't a problem to work. But it isn't my plan. So It should make something problem later. For example, it could occur address crashing when I try to insert data on after IDT.

(Because the memory address in IDTR is the same as IDT location. In fact, you can check IDT on 0x2021A0.)

After Fixing that, data was filled properly.


![HEX_IDT_WORK](/uploads/2017-07-10/OS/IDT_Work.png)

All of the data is ready.

But it didn't work....

So I knew if interrupt occurs, system down.

Weird.

No way! Did I make a  mistake about the pass on the processor?


```nasm

[BITS 64]
                     
global LoadGDTR, LoadTR, LoadIDTR
                        
SECTION .text

LoadGDTR:
    lgdt[rdi]
    ret
LoadTR:
    ltr di
    ret

LoadIDTR:
    lgdt[rdi]
    ret
```

Oh shi...

I make a mistake which is calling lgdt in LoadIDTR function.

So I change above code to below.


```nasm
[BITS 64]
                     
global LoadGDTR, LoadTR, LoadIDTR
                        
SECTION .text

LoadGDTR:
    lgdt[rdi]
    ret
LoadTR:
    ltr di
    ret

LoadIDTR:
    lidt[rdi]
    ret
```

I edit lgdt to lidt.

Thus, It works properly.

OMG, this posting is huge.


[You can check full-source-code on here](https://github.com/DevSDK/0SOS)


The left thing is the keyboard process using interrupt.
