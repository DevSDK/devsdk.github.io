---
layout: post
title: Round robin scheduling and Timeslice Context-Switching
date:   2017-09-18 22:46:20        
categories: development
languages:
- english
- korean
tags:
- 0SOS
- OS
- Operating System
- System
- Performance
- Task
- Scheduling
- MultiCore
- 64bit
---        

I've got working hard in Software maestro.

So I took this time to time.

It's a little bit late huh.

It makes me think a lot.

Also, code size is quite a bit large.

Anyway, in this time, I developed round robin scheduler for multitasking and Timeslice scheduling using IRQ0 timer interrupt.

Below image is a picture of executing.

That text is moved separately. (It worked simultaneously)

![worked!](/uploads/2017-09-18/0SOS/TaskWork.png)

It wasn't multilevel. So I made this every task can take 5ms cpu time.

From the Wikipedia, scheduling is an OS technique that makes possible to multiprogramming.

Simply, I wanna use several tasks simultaneously.

Many techniques there like FCFS, JSF, and ETC ... But I'll use the round-robin technique.

Priority isn't considered now. So CPU can take same cputime. Well, If I organize a multilevel queue, I can give priority.

It has a lot of considering things. 

First, The data will be added and deleted frequently. So a Linked-list will be proper data structure instead of an array-based list.

So I implemented Linked-list.

Yeah I know, Name is suck lol.

I named this LList shorter from LinkedList.

LList is a general data structure, so it has been implemented in '/GDS/' directory. 

Following codes is header file of LList.

I try to generalize this to insert list header in the node.

```c
#ifndef __LINKEDLIST_H__
#define __LINKEDLIST_H__
#include <Types.h>


#pragma pack(push, 1)
typedef struct _struct_Single_LinekdListNode
{
    void* NextNode; //Single Link Linked List
    QWORD ID; //Address or Data
}   LLIST_NODE_HEADER;

/*
    example of the element data structure.

typedef struct _Example_Data
{
    LLIST_DATA_HEADER header;
    
    int data1;
    char data2;

} Example;
*/

typedef struct _struct_LinkedListDescriptor
{
    void* FirstNode; 
    void* LastNode;
    QWORD Count; 
} LLIST;

#pragma pack(pop)

void InitializeLList(LLIST* _Ld);

void Push_Back_LList(LLIST* _Ld, void* _Item);
void Push_Front_LList(LLIST* _Ld, void* _Item);
void* Remove_LList(LLIST* _Ld, QWORD _ID);
void* Remove_Front_LList(const LLIST* _Ld);
void* Remove_Back_LList(const LLIST* _Ld);

void* FindLList(const LLIST* _Ld, QWORD _ID);


#endif /*__LINKEDLIST_H__*/
```

We need to define a HEADER. So I defined LLIST_NODE_HEADER in front of the structure for the data node.

Next is /GDS/LinkedList.c

```c
#include "LinkedList.h"
#include <Console/Console.h>
void InitializeLList(LLIST* _Ld)
{
    _Ld->Count = 0;
    _Ld->FirstNode = NULL;
    _Ld->LastNode  = NULL;   
}

void Push_Back_LList(LLIST* _Ld, void* _Item)
{   
    LLIST_NODE_HEADER* header = (LLIST_NODE_HEADER*)_Item;
    header->NextNode = NULL;
    if(_Ld->FirstNode == NULL)
    {
        _Ld->FirstNode = _Item;
        _Ld->LastNode  = _Item;
        _Ld->Count     = 1;
        return;
    }
    header = (LLIST_NODE_HEADER*)_Ld->LastNode;
    header->NextNode = _Item;
    _Ld->LastNode = _Item;
    _Ld->Count++;
}
void Push_Front_LList(LLIST* _Ld, void* _Item)
{
    LLIST_NODE_HEADER* header = (LLIST_NODE_HEADER*)_Item;
    header->NextNode = _Ld->FirstNode;
    if(_Ld->FirstNode == NULL)
    {
        _Ld->FirstNode  = _Item;
        _Ld->LastNode   = _Item;
        _Ld->Count      = 1;
        return;
    }
    _Ld->FirstNode = _Item;
    _Ld->Count++;
}
void* Remove_LList(LLIST* _Ld, QWORD _ID)
{
    LLIST_NODE_HEADER* pre_headaer = (LLIST_NODE_HEADER*)_Ld->FirstNode;

    for(LLIST_NODE_HEADER* iter_header = pre_headaer; iter_header != NULL; iter_header = iter_header->NextNode)
    {
        if(iter_header->ID == _ID)
        {
            if((iter_header == _Ld->FirstNode) && (iter_header == _Ld->LastNode) )
            {
                _Ld->FirstNode = NULL;
                _Ld->LastNode  = NULL;   
            }
            else if(iter_header == _Ld->FirstNode)
            {
                _Ld->FirstNode = iter_header->NextNode;
                
            }
            else if(iter_header == _Ld->LastNode)
            {
                _Ld ->LastNode = pre_headaer;

            } 
            else
            {
                pre_headaer->NextNode = iter_header->NextNode;
            }
            _Ld->Count--;
            return iter_header;
        }
        pre_headaer = iter_header;
    }
    
    return NULL;
}
void* Remove_Front_LList(const LLIST* _Ld)
{
    if(_Ld->Count == 0)
        return NULL;
    LLIST_NODE_HEADER* header = (LLIST_NODE_HEADER*)_Ld->FirstNode;
    return Remove_LList(_Ld, header->ID);
}
void* Remove_Back_LList(const LLIST* _Ld)
{
    if(_Ld->Count == 0)
        return NULL;
    LLIST_NODE_HEADER* header    = (LLIST_NODE_HEADER*)_Ld->LastNode;
    return Remove_LList(_Ld, header->ID);
}

void* FindLList(const LLIST* _Ld, QWORD _ID)
{
    for(LLIST_NODE_HEADER* iter = (LLIST_NODE_HEADER*) _Ld->FirstNode; iter!=NULL; iter = iter->NextNode)
    {
        if(iter->ID == _ID)
            return iter;
    }
    return NULL;
}
```

Linked list was implemented quite well. But Something problem waited for me. 

Problem is... 0SOS didn't have Heap Allocator. That mean, We cannot allocate dynamically. 

For fixing this problem and managing memory effectively, I'll use TCB pulling.

(First pre-assign specific area and allocating memory from the area like cake slice.)

TCB Pool was placed after 8MB area and I organize TaskStackPool on TCB pool.

I draw a picture for helping of understanding.

![MemoryMap](/uploads/2017-09-18/0SOS/MemoryMap.png)

(Powered by OneNote and my finger lol.)

Anyway, it has a structure like that.

(I'm so lazy to calculate above 8MB area.)

After 2MB area to 0x205C19 is 64bit kernel(IA-32e mode) area.

![Instruction](/uploads/2017-09-18/0SOS/InstructionLast.png)

From the book, ID was allocated by the first 32bit area was 0 in memory that was sliced to 32bit and 32bit

I don't wanna use like that. So I change properly.

I defined from 0bit to 55bit is the Index of ID and from 56bit to 63bit is status.

As Picture is:

![TCBID](/uploads/2017-09-18/0SOS/TCBID.png)

Tasking/Task.h.

```c
#ifndef __TASK_H__
#define __TASK_H__

#include <Types.h>
#include <GDS/LinkedList.h>
//SS, RSP, RFLAGS, CS, RIP.. etc.. Context
#define CONTEXT_REGISTER_COUNT     24
#define CONTEXT_REGISTER_SIZE       8

#define CONTEXT_OFFSET_GS           0
#define CONTEXT_OFFSET_FS           1
#define CONTEXT_OFFSET_ES           2
#define CONTEXT_OFFSET_DS           3
#define CONTEXT_OFFSET_R15          4
#define CONTEXT_OFFSET_R14          5
#define CONTEXT_OFFSET_R13          6
#define CONTEXT_OFFSET_R12          7
#define CONTEXT_OFFSET_R11          8
#define CONTEXT_OFFSET_R10          9
#define CONTEXT_OFFSET_R9           10
#define CONTEXT_OFFSET_R8           11
#define CONTEXT_OFFSET_RSI          12
#define CONTEXT_OFFSET_RDI          13
#define CONTEXT_OFFSET_RDX          14
#define CONTEXT_OFFSET_RCX          15
#define CONTEXT_OFFSET_RBX          16
#define CONTEXT_OFFSET_RAX          17
#define CONTEXT_OFFSET_RBP          18
#define CONTEXT_OFFSET_RIP          19
#define CONTEXT_OFFSET_CS           20
#define CONTEXT_OFFSET_RFLAG        21
#define CONTEXT_OFFSET_RSP          22
#define CONTEXT_OFFSET_SS           23

#define TASK_TCBPOOL_ADDRESS        0x800000
#define TASK_TCBPOOL_COUNT          4096

#define TASK_STACK_ADRESS           (TASK_TCBPOOL_ADDRESS + sizeof(TCB) * TASK_TCBPOOL_COUNT)
#define TASK_STACK_SIZE             8192

#define TASK_INVALID_ID             0xFFFFFFFFFFFFFFFF


//----- TCB STATUS DEFINITION

#define TASK_FREE                   0x0000000000000000
#define TASK_ALLOCATED              0x0100000000000000

#define TASK_STATE_MASK             0xFF00000000000000
#define TASK_INDEX_MASK             0x00FFFFFFFFFFFFFF


#pragma pack(push,1)
typedef struct __CONTEXT_STRUCT
{
    //RegisterData
    QWORD Registers[CONTEXT_REGISTER_COUNT];
} CONTEXT;

//Include the Linked List Header.
typedef struct __TCB_STRUCT
{
    LLIST_NODE_HEADER   list_header;
    QWORD               Flags;
    CONTEXT             Context;

    void*               StackAddress;
    QWORD               StackSize;
} TCB;  

//Management TCB Poll
typedef struct __TCB_POOL_MANAGER
{
    TCB* StartAddress;
    int MaxCount;
    int Count;

    int AllocatedCount;
}TCB_POOL_MANAGER;

typedef struct __SchedulerStruct
{
    TCB* Current_Runing_Task;

    int CpuTime;
    
    LLIST task_list;
}SCHEDULER;

#pragma pack(pop)

/// TASK POOL & TASK 


void InitTask(TCB* _Tcb, QWORD _Flags, QWORD _EntryPointAddress, void* _StackAddress, QWORD _StackSize);
void InitializeTCBPool();
TCB* AllocateTCB();
void FreeTCB(QWORD _ID);
TCB* CreateTask(QWORD _Flags, QWORD _EntryPointAddress);


//Link Assembly File
void ContextSwitch(CONTEXT* _CurrentContext, CONTEXT* _NextContext);
#endif /*__TASK_H__*/

```
I defined AllocateTCB, FreeTCB and InitalizeTCB functions and TCB_POOL_MANAGER structure.

And Masking for TCB-ID.

C-Code is:

```c
#include "Task.h"
#include <Utility/Memory.h>
#include <Descriptor/GDT.h>
#include <Console/Console.h>

static TCB_POOL_MANAGER g_TcbPoolManager;

void InitTask(TCB* _Tcb, QWORD _Flags, QWORD _EntryPointAddress, void* _StackAddress, QWORD _StackSize)
{
    _MemSet(_Tcb->Context.Registers, 0, sizeof(_Tcb->Context.Registers));
    
    // It add stack size because RSP, RBP in initialize is Task's stackpointer.
    _Tcb->Context.Registers[CONTEXT_OFFSET_RSP] = (QWORD)_StackAddress + _StackSize;
    _Tcb->Context.Registers[CONTEXT_OFFSET_RBP] = (QWORD)_StackAddress + _StackSize;
    
    //Segment Register Setup in Context 
    _Tcb->Context.Registers[CONTEXT_OFFSET_CS] = GDT_KERNEL_CODE_SEGMENT;
    _Tcb->Context.Registers[CONTEXT_OFFSET_DS] = GDT_KERNEL_DATA_SEGMENT;
    _Tcb->Context.Registers[CONTEXT_OFFSET_ES] = GDT_KERNEL_DATA_SEGMENT;
    _Tcb->Context.Registers[CONTEXT_OFFSET_FS] = GDT_KERNEL_DATA_SEGMENT;
    _Tcb->Context.Registers[CONTEXT_OFFSET_GS] = GDT_KERNEL_DATA_SEGMENT;
    _Tcb->Context.Registers[CONTEXT_OFFSET_SS] = GDT_KERNEL_DATA_SEGMENT;
    
    //Next run instruction setup
    _Tcb->Context.Registers[CONTEXT_OFFSET_RIP] = _EntryPointAddress;

    // 0 NT  IOPL  OF DF IF TF SF ZF 0  AF 0  PF 1  CF
    // 0  0  0  0  0  0  1  0  0  0  0  0  0  0  0  0
    _Tcb->Context.Registers[CONTEXT_OFFSET_RFLAG] |= 0x0200;   
    //Setup TCB Block
    _Tcb->StackAddress  = _StackAddress;
    _Tcb->StackSize     = _StackSize;
    _Tcb->Flags         = _Flags;
 }

 void InitializeTCBPool()
 {
     //Initialize Task Pool started from 8MB area and Manager. 
    _MemSet(&(g_TcbPoolManager), 0, sizeof(g_TcbPoolManager));
    g_TcbPoolManager.StartAddress = (TCB*)TASK_TCBPOOL_ADDRESS;

    _MemSet(TASK_TCBPOOL_ADDRESS,0,sizeof(TCB) * TASK_TCBPOOL_COUNT);
    for(int i = 0; i < TASK_TCBPOOL_COUNT; i++)
        g_TcbPoolManager.StartAddress[i].list_header.ID = i;

    g_TcbPoolManager.MaxCount = TASK_TCBPOOL_COUNT;
    g_TcbPoolManager.AllocatedCount = 1;
}
 //       STATE
 //63 ------------ 55 -------0
 // 0 0 0 0 0 0 0 0 | address|

 TCB* AllocateTCB()
 {
    TCB* EmptyTCB;
    //If TCBPool fill, return NULL.
    if(g_TcbPoolManager.Count == g_TcbPoolManager.MaxCount)
        return NULL;
    //Linear searching in TCBPool at Free status.
    for(int i = 0; i < g_TcbPoolManager.MaxCount; i++)
    {
        if((g_TcbPoolManager.StartAddress[i].list_header.ID & TASK_STATE_MASK) == TASK_FREE )
        {
            EmptyTCB = &(g_TcbPoolManager.StartAddress[i]);
            break;
        }
    }
    //Changing status TASK_ALLOCATED to ALLOCATED using or operation and generate ID value using Allocate count.
    QWORD id = (QWORD) (g_TcbPoolManager.AllocatedCount);
    EmptyTCB->list_header.ID = (( id | TASK_ALLOCATED));
    g_TcbPoolManager.Count++;
    g_TcbPoolManager.AllocatedCount++;

    
    if(g_TcbPoolManager.AllocatedCount ==0)
        g_TcbPoolManager.AllocatedCount = 1;
    
    return EmptyTCB;
}
void FreeTCB(QWORD _ID)
{
    //Extracy Index area from _ID
    QWORD index = _ID & TASK_INDEX_MASK;
    //Initialize TCB Context
    _MemSet(&(g_TcbPoolManager.StartAddress[index].Context), 0, sizeof(CONTEXT));
    //Free
    g_TcbPoolManager.StartAddress[index].list_header.ID = index;
    g_TcbPoolManager.Count--;
}
TCB* CreateTask(QWORD _Flags, QWORD _EntryPointAddress)
{
    TCB* task = AllocateTCB();

    if(task == NULL)
        return NULL;
    //Get stack address. TCBPool end address + STCKSIZE * INDEX.
    void* StackAddress = (void*)(TASK_STACK_ADRESS + 
        (TASK_STACK_SIZE * (task->list_header.ID & TASK_INDEX_MASK)));
    
    InitTask(task,  _Flags, _EntryPointAddress, StackAddress, TASK_STACK_SIZE);
    
    //Register scheduler
    AddTaskToScheduler(task);
    return task;
}
 
```

Finally, We are going to write the scheduler code. 

```c
#ifndef __SCHEDULER_H__
#define __SCHEDULER_H__

#include <Types.h>
#include <Tasking/Task.h>

//Default CPU Time
#define TASK_TIME                   5


void InitializeScheduler();
void SetCurrentRunningTask(TCB* _Tcb);
TCB* GetCurrentRunningTask();
TCB* GetNextTask();
void AddTaskToScheduler(TCB* _Tcb);
void Schedule();
BOOL ScheduleInInterrupt();
void DecreaseProcessorTime();
BOOL IsProcessorTimeExpired();


#endif /*__SCHEDULER_H__*/
```

Header file.

That contain functions for scheduling and initialize and maximum cpu usage time for Round Robin Scheduling. 

ContextSwitching technique is quite different between Calling Schedule function and Calling IRQ0 Timerinterupt.

When we use the Schedule function, we can just do ContextSwitch. But When we interrupt, We need to designate context with changing the context in IST

I cannot draw this (With my horrible draw technique)

Shortly, It will be switched automatically because the IST area for using interrupt would be saved context.

Let's see the source code.

```c
#include "Scheduler.h"
#include <Tasking/Task.h>
#include <Interrupt/Interrupt.h>
#include <Descriptor/IDT.h>
#include <Utility/Memory.h>
#include <Console/Console.h>
static SCHEDULER g_Scheduler;
//Initialize TCBPool and TaskList.
void InitializeScheduler()
{
    InitializeTCBPool();
    InitializeLList(&(g_Scheduler.task_list));
    //Designate Shell Task to Task
    g_Scheduler.Current_Runing_Task = AllocateTCB();
}
void SetCurrentRunningTask(TCB* _Tcb)
{
    g_Scheduler.Current_Runing_Task = _Tcb;
}
TCB* GetCurrentRunningTask()
{
    return g_Scheduler.Current_Runing_Task;
}
TCB* GetNextTask()
{
    if(g_Scheduler.task_list.Count == 0)
        return NULL;

    return (TCB*) Remove_Front_LList(&g_Scheduler.task_list);
}
void AddTaskToScheduler(TCB* _Tcb)
{
    Push_Back_LList( &(g_Scheduler.task_list), _Tcb);
}   
void Schedule()
{
    //If scheduling list is empty, exit this function.
    if(g_Scheduler.task_list.Count == 0)
        return;

    //Disable Inerrupt.
    BOOL interrupt_status = SetInterruptFlag(FALSE);
    TCB* task = GetNextTask(); 
    //If next task is NULL,
    if(task == NULL)
    {
        //return after restore interrupt
        SetInterruptFlag(interrupt_status);
        return;
    }
    //Register current task in scheduling list.
    TCB* pre_task = g_Scheduler.Current_Runing_Task;
    AddTaskToScheduler(pre_task);   
    
    //Changing running task.
    g_Scheduler.Current_Runing_Task = task;
    //Context Switch
    ContextSwitch(&(pre_task->Context), &(task->Context));
    //Initialize Cputime 
    g_Scheduler.CpuTime = TASK_TIME;
    //Restore Interrupt.
    SetInterruptFlag(interrupt_status);

}
//Calling by interrupt.
BOOL ScheduleInInterrupt()
{
    Get the next task.
    TCB* task = GetNextTask();
    if(task == NULL)
    {
        return FALSE;
    }

    //Context address stored in IST Stack.
    void* ContextAddress = IST_POINTER + IST_SIZE - sizeof(CONTEXT);
    
    TCB* running_task = g_Scheduler.Current_Runing_Task;
    //Save context.
    _MemCpy(&(running_task->Context), ContextAddress, sizeof(CONTEXT));
    g_Scheduler.Current_Runing_Task = task;
    AddTaskToScheduler(running_task);
    //Switch context and restore
    _MemCpy(ContextAddress, &(task->Context),sizeof(CONTEXT));
    g_Scheduler.CpuTime = TASK_TIME;
    return TRUE;
}
void DecreaseProcessorTime()
{
    if(g_Scheduler.CpuTime > 0)
        g_Scheduler.CpuTime--;
}
BOOL IsProcessorTimeExpired()
{
    if(g_Scheduler.CpuTime  <= 0)
        return TRUE;
    return FALSE;   
}

```
I think I've written enough comment.

Now we are ready to schedule.

Now we can possible timeslice multitasking with IRQ0 Timer Interrupt.

I add a function in Interrupt/InterruptHandler.c

```c
void TimerInterruptHandler(int _Vector)
{

    SendPIC_EOI(_Vector - PIC_IRQ_VECTOR);

    DecreaseProcessorTime();
    if(IsProcessorTimeExpired())
    {
        ScheduleInInterrupt();    
    }
    
}
```
IRQ0 Interrupt in Interrupt/InterruptService.asm  
```nasm
ISRTimer:
    SAVECONTEXT
    mov rdi, 32
    call TimerInterruptHandler
    LOADCONTEXT
    iretq

```

I add the following code in shell file.

```c


void TestTask1()
{
    BYTE data;
    int i =  0, ix =0, iy = 0, iMargin;
    CHARACTER_MEMORY* video = (CHARACTER_MEMORY*)CONSOLE_VIDEO_MEMORY;
    TCB* task = GetCurrentRunningTask();
    iMargin = (task->list_header.ID & TASK_INDEX_MASK) %10;
    while(1)
    {
        switch(i)
        {
            case 0:
                ix++;
                if(ix>=(CONSOLE_WIDTH - iMargin))
                    i = 1;
                break;
            case 1:
                iy++;
                if(iy>=(CONSOLE_WIDTH - iMargin))
                    i = 2;
                break;    
            case 2:
                ix--;
                if(iy<iMargin)
                    i = 3;
                break;
            case 3:
                iy--;
                if(iy < iMargin)
                    i = 0;
                break;
        }   
        video[iy * CONSOLE_WIDTH + ix].bCharactor = data;
        video[iy * CONSOLE_WIDTH + ix].bAttribute = data & 0x0F;
        data++;
        Schedule();
    }
    

}

void TestTask2()
{
    int i =0, iOffset;
    
    CHARACTER_MEMORY* video = (CHARACTER_MEMORY *)CONSOLE_VIDEO_MEMORY;
    TCB* task = GetCurrentRunningTask();
    char data[4] = {'-','\\','/','|'};

    iOffset = (task->list_header.ID & TASK_INDEX_MASK ) * 2;
    iOffset = CONSOLE_WIDTH * CONSOLE_HEIGHT - (iOffset % (CONSOLE_WIDTH * CONSOLE_HEIGHT));

    while(1)
    {
        video[iOffset].bCharactor = data[i %4];
        video[iOffset].bAttribute = (iOffset % 15) + 1;

        i++;
        Schedule();
    }
}




void Command_CreateTask(const char* _Parameter)
{
    PARAMETERLIST parameter_list;
    char type[30];
    char count[30];
    InitializeParameter(&parameter_list, _Parameter);
    GetNextParameter(&parameter_list, type);
    GetNextParameter(&parameter_list, count);

    long idx = 0;
    long cnt = 0;
    _atoi(type, &idx,10);
    _atoi(count, &cnt,10);
    int i = 0; 
    switch (idx)
    {
        case 1:
            for( i =0; i<cnt; i++)
            {
                if(CreateTask(0,(QWORD)TestTask1) == NULL)
                    break;
            }      
            _Printf("Task 1 %d Created\n", i);
            break;
        case 2:
            for( i =0; i<cnt; i++)
            {
                if(CreateTask(0,(QWORD)TestTask2) == NULL)
                    break;
            }      
            _Printf("Task 2 %d Created\n", i);
            break;
    }

}
```

We can create the task (one of type 1 or 2) using command createtask.

Type 2 makes the pinwheel and type 2 is like movement string line.

One of pinwheel is taken by one task.

Anyway, It is clearly worked code.

Before we worked, It has a lot of problems. 

One of the problems is

![Excepton7](/uploads/2017-09-18/0SOS/Exception7.png)

Exception7.

Specific is "Device Not Available" code 7 in x86 sytem.

From Google, that problem is related to FPU. But my OS doesn't support FPU so I'm confused.

And I found why it makes that.

I defined 25 register in Task.h, even we had 24 register.

Damm.

After fixing that, It makes Exception 14 Page Fault.

This problem was made from the Liked List.

After fixing that, it worked.

Well, I read the memory map and do other things in the debugging process. 

Finally, It has just miss calling function and linked list problem so I don't write that.


Now, Multitasking has worked!

Now This project will be frozen.

I think it resumes after Software maestro. 

IDK.


If I try to develop, I'll write this.

