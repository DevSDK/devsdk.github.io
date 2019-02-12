---
layout: post
title: Keyboard Driver Update-Interrupt
date:   2017-07-12 23:49:20        
categories: development
tags:
- 0SOS
- OS
- Operating System
- System
- Paging
- Interrupt
- 64bit
---        

I think this article was short.

Today I cannot focus strangely.

In the morning I could focus greatly but now I can't.

Anyway, at this time, I guess this article wouldn't too long.

Until now we use a Port Map IO that used buffer from PS/2's memory, but if we use the interrupt, we can't use that buffer.

Because the data load and de-load time is too different.

So I made InputBuffer as you well-know.

Data Structure is Queue.

I considered about directory which would be used generally.

DS makes an image about Nintendo DS, so I hate it.

DataStructure is too long.

SO I just decide UDS (Universal Data Strcture).

I made Queue.h and Queue.c files in UDS directory.

That was a Circular Queue.

That was the general queue, so you can understand easily if you have a little knowledge.

Implemented by C, It can be Identify by the first parameter that Queue Descriptor 

Anyway, Below code is a specific implementation.


```c
//Queue.h
#ifndef __QUEUE_H__
#define __QUEUE_H__
#include <Types.h>

#pragma pack(push, 1)

typedef struct _struct_QueueDescriptor
{
    int DataSize;
    int MaxDataCount;

    void* MemoryArray;
    unsigned int Front;
    unsigned int Rear;

    BOOL isLastPut;
} QUEUE;

#pragma pack(pop)

void InitializeQueue(QUEUE* _QD, void* _QueueBuffer, int _MaxDataCount, int _DataSize);
BOOL IsQueueFull(const QUEUE* _QD);
BOOL IsQueueEmpty(const QUEUE* _QD);
BOOL PushQueue(QUEUE* _QD, const void* _Src);
BOOL PopQueue(QUEUE* _QD, void* _Dst);

#endif /*__QUEUE_H__*/

```

It just queue as you know.

Skip description.

```c
//Queue.c
#include "Queue.h"
#include <Utility/Memory.h>
void InitializeQueue(QUEUE* _QD, void* _QueueBuffer, int _MaxDataCount, int _DataSize)
{
    _QD->MaxDataCount = _MaxDataCount;
    _QD->DataSize = _DataSize;
    _QD->MemoryArray = _QueueBuffer;
    _QD->Front = 0;
    _QD->Rear = 0;
    _QD->isLastPut = FALSE;
}
BOOL IsQueueFull(const QUEUE* _QD)
{
    if((_QD->Rear == _QD->Front) && (_QD->isLastPut == TRUE))
        return TRUE;
    return FALSE;
}
BOOL IsQueueEmpty(const QUEUE* _QD)
{
    if((_QD->Rear == _QD->Front) && (_QD->isLastPut == FALSE))
        return TRUE;
    return FALSE;
}

BOOL PushQueue(QUEUE* _QD, const void* _Src)
{
    if(IsQueueFull(_QD))
        return FALSE;
    _MemCpy(((char*)_QD->MemoryArray) + (_QD->DataSize * _QD->Front),  _Src, _QD->DataSize);

    _QD->Front = (_QD->Front + 1) % _QD->MaxDataCount;
    _QD->isLastPut = TRUE;
    return TRUE;
}
BOOL PopQueue(QUEUE* _QD, void* _Dst)
{
    if(IsQueueEmpty(_QD))
        return FALSE;
    _MemCpy(_Dst, (char*)_QD->MemoryArray + (_QD->DataSize * _QD->Rear ) , _QD->DataSize);

    _QD->Rear = (_QD->Rear + 1) % _QD->MaxDataCount;
    _QD->isLastPut = FALSE;

    return TRUE;
}
```
If you don't wanna read the code, you can skip and mind it is just queue as well. 

Anyway, we should make a keyboard input buffer using this data structure and use it on Interrupt Handling function.

First, Write the General Queue in Keyboard.h.

Also, make a structure for key-data.

```c
//Keybuard.h
//....skip

#define KEY_BUFFER_SIZE 100

typedef struct _KeyDataStruct
{
    BYTE ScanCode;
    BYTE ASCIICode;
    BYTE Flags;
} KEYDATA;


static QUEUE g_KeyBufferQueue;

static KEYDATA g_KeyBufferMemory[KEY_BUFFER_SIZE];

void InitalizeKeyboardBuffer();
BOOL ConvertScanCodeWithPushKeyQueue(BYTE _ScanCode);
BOOL GetKeyData(KEYDATA* _data);

//....skip
```

Above functions' implementation is below.

```c
//Keyboard.c
//...skip
void InitalizeKeyboardBuffer()
{
    InitializeQueue(&g_KeyBufferQueue, g_KeyBufferMemory, KEY_BUFFER_SIZE, sizeof(KEYDATA));
}
BOOL ConvertScanCodeWithPushKeyQueue(BYTE _ScanCode)
{
    KEYDATA keydata;
    keydata.ScanCode = _ScanCode;
    BOOL result = FALSE;
    if(ConvertScancodeToASCII(_ScanCode, &keydata.ASCIICode, &keydata.Flags) == TRUE)
    {
        BOOL interrupt_status = SetInterruptFlag(FALSE);
        result = PushQueue(&g_KeyBufferQueue, &keydata);
        SetInterruptFlag(interrupt_status);
    }
    return result;


BOOL GetKeyData(KEYDATA* _data)
{
    BOOL result = FALSE;

    if(IsQueueEmpty(&g_KeyBufferQueue))
        return FALSE;

    BOOL interruptstatus = SetInterruptFlag(FALSE);
    result = PopQueue(&g_KeyBufferQueue,_data);
    SetInterruptFlag(interruptstatus);
    return result;
}


}
//...skip
```

From above, Initialization queue for buffer function, Pushing Keydata from ScanCode into the queue function and Getting key data from the Queue function.

You can see below the line on pushing queue, it makes turning off interrupts.

```c
BOOL interrupt_status = SetInterruptFlag(FALSE);
```

And after pushing, that flag was restored.

Because I don't wanna make a problem related to synchronization.

While queue operation, we are blocking interrupt function to avoid problems like change operation order.

SetInterruptFlag function was defined in Utility/Flags.h

Implementationn content is:

```c
//Flags.c
BOOL SetInterruptFlag(BOOL _flag)
{
    QWORD flag;
    flag = ReadFlags();

    if(_flag == TRUE)
        EnableInterrupt();
    else
        DisableInterrupt();

    if(flag & 0x0200)
        return TRUE;
    else
        return FALSE;
}
```

It was made by ReadFlags, EnagleInterrupt, and DisableInterrupt which were we made.

And next, the LED and Keyboard activation request and waiting response code's changed.

```c
BOOL WaitACKWithScanCodePushQueue()
{
    BOOL result = FALSE;
    for(int i = 0; i< 100; i++)
    {
        for(int j = 0 ; j < 0xFFFF; j++)
        {
            if(PS2CheckOutputBufferNotEmpty())
                break;
        }        
        BYTE data = PortIO_InByte(0x60);
        if(data == 0xFA)
        {
            result = TRUE;
            break;
        }
        else
        {
            ConvertScanCodeWithPushKeyQueue(data);
        }
    }
    return result;     
}
```

Add code above.

```c
    for(int i=0; i< 100; i++)
    {
        //....
    }
```

I add awaiting function on ACK awaiting code above.


```c
result = WaitACKWithScanCodePushQueue();

    if(result == FALSE)
        return FALSE;
```

[You can see specifically](https://github.com/DevSDK/0SOS/blob/master/02_Kernel64/Source/Driver/Keyboard/PS2Keyboard.c)

And Interrupt Handler part function can process data cause below code appended.


```c
   if(PS2CheckOutputBufferNotEmpty() == TRUE)
    {
        BYTE scancode = PS2GetKeyboardScanCode();
        ConvertScanCodeWithPushKeyQueue(scancode);
    }
```

And Change the input process part in kernel entry to use Queue.


```c
        if(GetKeyData(&keydata) == TRUE)
        {
            if(keydata.Flags & KEY_DOWN)
            {
                temps[0] = keydata.ASCIICode;
                PrintVideoMemory(i++, 17, 0x0C, temps);
            }
        }
```

Now we can process input using the queue.

Also Interrupt too.

It looks the same, but an internal huge changed.

![Result](/uploads/2017-07-12/OS/Result.png)

Now we use the input queue, So If we wanna make some Input Driver, we can use the queue.

Simply, It get a layer.

I think I can use it when I write USB Keyboard Driver.


Thanks for reading.