---
layout: post
title: Definition of DataStructure related Paging, Prepare to jump to 64 bit.
date:   2017-06-30 09:21:20        
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
- Booting
- 64bit
---        

It's the time, to 64 bit.

We didn't enable paging and define data structure because 32bit protection mode is before IA-32e mode.

Anyway, We need to define a data structure for memory paging function.

There are two methods exist.

First one is 4-step-paging that would slice memory every 2MB.

The second one is 5-step-paging that would slice memory every 4KB.

In this picture describe 5-step-paging using 4KB, but I'll use 4-step-paging using 2MB.

No PT.

![Paging!](/uploads/2017-06-30/OS/PageTable.png)

One of entry in Page Directory Table.

512 2MB Entries can be stored in this Table.

That means each directory can be present 512 * 2MB = 1GB. 

We need the 64-page directory point because we will support 64GB.

So We need only one entry in PML4 table.

Shortly, Securing memory area is PML4 table, Page Directory Point Table and Page Directory Table. 

In source code that was named PMl4, PDPT, and PD.

Also, BITFLAG was supported because A lot of Flags has existed that would be overlapped.

Following is Memory assign size for this data structure.

512 8byte of PML4 Entry would use 512 * 8byte. 

512 8byte of PDPT Entry would use 512 * 8byte.

512 8byte of PD Entry would use 512 * 64 (support 64GB).

So We need 264KB.

We'll assign 64-bit kernel to 2MB area, so let's store to 1~2MB area.

```c

#ifndef __PAGE_H__
#define __PAGE_H__

#include "Types.h"

#define PAGE_FLAG_P            0x00000001
#define PAGE_FLAG_RW        0x00000002
#define PAGE_FLAG_US        0x00000004
#define PAGE_FLAG_PWT        0x00000008
#define PAGE_FLAG_PCD        0x00000010
#define PAGE_FLAG_A            0x00000020
#define PAGE_FLAG_D            0x00000040
#define PAGE_FLAG_PS        0x00000080
#define PAGE_FLAG_G            0x00000100
#define PAGE_FLAG_PAT        0x00001000    
#define PAGE_FLAG_EXB        0x80000000    

#define PAGE_FLAG_DEFAULT    (PAGE_FLAG_P | PAGE_FLAG_RW)
#define PAGE_TABLE_SIZE        0x1000 //4KB
#define PAGE_DEFAULT_SIZE    0X200000

#define PAGE_MAX_ENTRY_COUNT        512

#pragma(push, 1)



/*

    For IA-32e Paging
    IA-32e Address Structure
    63            48 47    39 38               30 29       21 20            0
    |SIGNEXTENSION| PML4 | DIRECTORY POINTER | DIRCTORY  |    OFFSET     |

    PML4 Reference PML4 ENTRY
    and, that Reference DIRECTORY POINTER ENTRY using DIRECTORY POINTER
    and, that Reference DIRECTORY ENTRY using DIRECTORY 
    and, DIRECTORY + OFFSET is Memory Address. 
    
    so, We Need Space for this Structure
    
    PML4 Table Need 512 * 8 Byte = 4KB
    PAGE DIRECTORY POINTER Table Need 512 * 8 Byte = 4KB
    PAGE DIRECTORY Need 512 * 8 Byte * 64 = 256KB (for 64GB Memory)
    
    So we using 4KB + 4KB+ 256KB = 264KB Memory Space.

    The following code is its implementation.
        
    We Use 4 Level Paging, So NOT USE PTENTRY.
*/

typedef struct __Struct_PageEntry
{    
    
    /*0----------------31 bit */
    DWORD dwLowAddress;
    /*32---------------64 bit */
    DWORD dwHighAddress;

} PML4ENTRY, PDPTENTRY, PDENTRY, PTENTRY;    

#pragma(pop)

void InitializePageTable();
void SetPageEntryData(PTENTRY* pEntry, DWORD dwHighBaseAddress, 
                      DWORD dwLowBaseAddress, DWORD dwLowFlag, DWORD dwHighFlag);



#endif /*__PAGE_H__ */

```

Damm, Comment was broken.

It looks like this.

![Quite Pretty](/uploads/2017-06-30/OS/64BitMemory.png)

__Struct_PageEntry is defined for 64 bit sized Table Entry.

PTENTRY structure isn't used (It's only for 5-step-paging).

```c


#include "Page.h"



void InitializePageTable()
{

    PML4ENTRY*    pml4entry  = (PML4ENTRY*) 0x100000;
    PDPTENTRY*    pdptentry  = (PDPTENTRY*) 0x101000;
    PDENTRY*    pdentry    = (PDENTRY*    ) 0x102000;

    SetPageEntryData(&pml4entry[0], 0x00, 0x101000, PAGE_FLAG_DEFAULT, 0);

    for(int i = 1; i< PAGE_MAX_ENTRY_COUNT; i++)
    {
        SetPageEntryData(&pml4entry[i], 0,0,0,0);
    }

    for(int i = 0; i < 64; i++)
    {
        SetPageEntryData(&pdptentry[i], 0, 0x102000 + i * PAGE_TABLE_SIZE,
                         PAGE_FLAG_DEFAULT, 0);
    }

    for(int i=64; i < PAGE_MAX_ENTRY_COUNT; i++)
    {
        SetPageEntryData(&pdptentry[i], 0, 0, 0, 0);
    }

    DWORD LowMapping = 0; 
    
    /*
        'high' for Calculate out of 32bit area. using HighAddressArea 
    */

    for(int i=0; i<PAGE_MAX_ENTRY_COUNT * 64; i++)
    {
        DWORD high = (i * (PAGE_DEFAULT_SIZE >> 20) ) >> 12;
        SetPageEntryData(&pdentry[i], high, LowMapping, 
                        PAGE_FLAG_DEFAULT | PAGE_FLAG_PS, 0);                

        LowMapping += PAGE_DEFAULT_SIZE;
    }
     

}


void SetPageEntryData(PTENTRY* pEntry, DWORD dwHighBaseAddress, DWORD dwLowBaseAddress,
                      DWORD dwLowFlag, DWORD dwHighFlag)
{
    pEntry->dwLowAddress  = dwLowBaseAddress  | dwLowFlag;
    pEntry->dwHighAddress = (dwHighBaseAddress & 0xFF )| dwHighFlag;
}

```

It looks quite complex.

But it isn't.

">>20>>12" is the operation of address over than 32-bit area.

I present 64-bit using a struct.

We will store data by FLAG before we defined

![MsPaint](/uploads/2017-06-30/OS/Memory.png)


And add initialize function in main.c.

```c

    PrintVideoMemory(5,7, 0x0F,"Initalization PML4, PDPT, PD .........................");
    InitializePageTable();
    PrintVideoMemory(60,7,0x0A,"[SUCCESS]");

```

Memory size check is simple, so it prints just SUCCESS.


Let's see in VM.


![Woosh!](/uploads/2017-06-30/OS/PageInitOut.png)

I'm glad that function was added

[You can find full source code in GITHUB.](https://github.com/DevSDK/0SOS)


STAR PLZ :)