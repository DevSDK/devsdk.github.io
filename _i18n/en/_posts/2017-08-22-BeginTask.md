---
layout: post
title: TCB and Context and ContextSwitch
date:   2017-08-22 20:00:20        
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
- Performance
- Task
- MultiCore
- 64bit
---        

Before I named the data structure 'Universal Data Structure' shortly 'UDS', I think General is more properly instead of Universal.

So I changed UDS to GDS.


I implemented Context Switching and Task for multitasking that was not yet supported.

It doesn't look massive. But It is task switching definitely.

![Result](/uploads/2017-08-22/ShellContext.png)

Before we define "Task" we need to check out about Context.

This Context, it was leaned OS in college.

It's Process and Task's executed status.

Context is just Register stored values and Stack.

Context Switching is literally switching, that would execute here and there.

The task is work that can be processed separately.


In Task, Code and Data can be shared but Stack and Context keep separation.

Latency time will be increased when you use timeslice instead of the batch process.

So I'll use Timeslice multitasking.

Timeslice multitasking is context switching every millisecond by IRQ0 interrupt.

```c
//shell.c
static TCB g_task[2] = {0.};
static QWORD test_stack[1024] = {0,};

void TaskTask()
{
    int iteration = 0;
    while(1)
    {
        _Printf("[%d] Message from test task Press any key to switching\n",iteration++);
        _GetCh();
        ContextSwitch(&g_task[1].Context, &g_task[0].Context);
    }

}

void Command_CreateTask(const char* _Parameter)
{
    KEYDATA key;
    InitTask(&g_task[1],1,0, TaskTask, test_stack, sizeof(test_stack));
    
    int iteration = 0;
    while(1)
    {
        _Printf("[%d] message from shell Press any key to switching\n", iteration++);
        if(_GetCh() =='q')
            break;
        ContextSwitch(&g_task[0].Context, &g_task[1].Context);  
        }

}
```

CreatTask function, it works for the creation of task and initialization.

Context Switching, switching context function.

Task Control Block, it is data-structure for context.

And Defining offsets and context.

I created Directory "Tasking"


Tasking/Task.h:

```c
#ifndef __TASK_H__
#define __TASK_H__

#include <Types.h>

//SS, RSP, RFLAGS, CS, RIP..  Context
#define CONTEXT_REGISTER_COUNT     25
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

#pragma pack(push,1)
typedef struct __CONTEXT_STRUCT
{
    QWORD Registers[CONTEXT_REGISTER_COUNT];
} CONTEXT;

typedef struct __TCB_STRUCT
{
    CONTEXT Context;
    QWORD ID;
    QWORD Flags;

    void* StackAddress;
    QWORD StackSize;
} TCB;
#pragma pack(pop)

void InitTask(TCB* _Tcb, QWORD _ID, QWORD _Flags, QWORD _EntryPointAddress, void* _StackAddress, QWORD _StackSize);

//Link Assembly File
void ContextSwitch(CONTEXT* _CurrentContext, CONTEXT* _NextContext);
#endif /*__TASK_H__*/   
```

It has many definitions, but there are just index and registers.

It'll be great for statically assigning value in the array.

And than Context (It is just register-values)

And TCB (It can be Task Control Block and Thread Control Block)

TCB contain Context, ID, Flags, Stack Address, and Stack size

Tasing/Task.c:

```c

#include "Task.h"
#include <Utility/Memory.h>
#include <Descriptor/GDT.h>
void InitTask(TCB* _Tcb, QWORD _ID, QWORD _Flags, QWORD _EntryPointAddress, void* _StackAddress, QWORD _StackSize)
{
    _MemSet(_Tcb->Context.Registers, 0, sizeof(_Tcb->Context.Registers));
    
    //초기화 과정의 RSP, RBP 해당 Task의 Stack Pointer 기 떄문에 + Size 
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
    _Tcb->ID            = _ID;
    _Tcb->StackAddress  = _StackAddress;
    _Tcb->StackSize     = _StackSize;
    _Tcb->Flags         = _Flags;
 }
```

It is just function for the initialize of members.

Segment register kernel segment and initialize register's initial values.

And next code of execution assigns in RIP register(PC, Program counter)'s EntryPoint.

And ContextSwitch function linked with assembly code.

```nasm

[BITS 64]

global ContextSwitch

SECTION .text   

%macro SAVECONTEXT 0
    push rbp
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    mov ax, ds
    push rax
    mov ax, es
    push rax
    push fs
    push gs

    mov ax, 0x10
    mov ds,ax
    mov es,ax
    mov gs,ax
    mov fs,ax

%endmacro


%macro LOADCONTEXT 0
    pop gs
    pop fs
    pop rax
    mov es, ax
    pop rax
    mov ds, ax

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    pop rbp

%endmacro

ContextSwitch:
    push rbp
    mov rbp, rsp
    ;Push RFLAGS in stack
    pushfq
    ;if _CurrentContext is NULL
    cmp rdi,0
    je .LoadContext
    popfq
    push rax    ;For use Context Offset 

    ;Save SS RSP RFLAGS CS RIP Registers
    mov ax, ss
    mov qword[rdi + 23 * 8], rax
    mov rax, rbp

    ;reset value to before, RSP Contextswitch  -(ReturnAddress + RBP)
    add rax, 16
    mov qword[rdi + 22 * 8], rax

    ;Push FLAGS in stack
    pushfq
    pop rax
    mov qword[rdi + 21 * 8], rax
    
    ;Save Cs Segment
    mov ax, cs
    mov qword[rdi + 20 * 8], rax

    mov rax, qword[rbp + 8]
    mov qword[rdi + 19 * 8], rax

    pop rax
    pop rbp
    ;Context->Registers
    add rdi, 19*8
    mov rsp, rdi
    sub rdi, 19*8

    SAVECONTEXT

.LoadContext:
    mov rsp, rsi
    LOADCONTEXT
    iretq

```
If the first parameter Null(0) it is ShellTask.

Jump to .LoadContext

If working like that, We will context load by the second parameter.

If not, it would save context.

And then load by the second parameter.

So It's done of context-switching.



Huh.