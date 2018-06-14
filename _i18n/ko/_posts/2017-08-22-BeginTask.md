---
layout: post
title: TCB와 Context, 그리고 ContextSwitch
date:   2017-08-22 20:00:20		
categories: development
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



이것저것 일이 생기고 시간을 퍼부울 수 있는 환경이 아니라 틈틈히 작업했다

이전에 범용 자료구조라고 Universal Data Structure 해서 UDS라고 디렉토리 이름을 지어줬는데

좀더 고민해보고 찾아보니까  

Universal 보단 General 이 더 어울릴꺼같아서 UDS에서 GDS로 이름을 바꾸었다.



본문으로 넘어가서


아직 멀티테스킹 그런건 아니지만, 그것을 지원하기 위한 첫 단추로 Task를 정의하고

Context Switch 를 구현했다.

뭐 화려하고 멋진 그런 모양세는 아니지만

정적이긴 하지만 테스트로 작성한 두 테스크간의 스위칭을 볼 수 있다.

![결과 화면](/uploads/2017-08-22/ShellContext.png)

일단, 테스크를 정의하기에 앞서 Context, 문맥이라고 하는부분을 짚고 넘어갈 필요가 있다.

이 문맥이라는 녀석이, OS 개론을 배웠다면 알겠지만 

프로세스면 프로세스, 테스크면 테스크 의 실행 상태를 의미한다.

뭐 실행 상태라고 하니까 뭔가 이상한데

말그대로 Register의 값들, Stack등을 문맥이라고 한다.

그 컨텍스트를 말그대로 교환한다는 뜻이고, 이거 실행하다 저거 실행하는걸 할 수 있다는 뜻이다.

Task는 개별적으로 처리가 가능한 작업을 의미하는데,

테스크에서 Code, Data는 공유가 가능, Stack, Context 는 독립적임을 유지한다. 

테스크의 작업을 일괄 처리 방식으로 처리할때보다 시분할로 나누어 처리할때 레이턴시가 많이 증가한다.

따라서, 0SOS는 시분할 멀티테스킹 기법을 사용할 것이다.

시분할 멀티테스킹은 PIT 컨트롤러의 수 밀리세컨드에서 수십 밀리세컨드 단위로 IRQ 0 인터럽트에 맞춰 테스크를 전환하는 기법이다.

아무튼 OS개론적인 이야기는 일단 뒤로 두고, 위 이미지의 실행 코드는 다음과 같다.

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



대충 본다면, CreateTask

테스크를 초기화(생성)하는 함수다.

ContextSwitch Context를 교환해주는 함수다.

Task Control Block 해서 TCB 구조체를 정의해줬고

Context에 대해 정의하고 각 Offset을 만들어줬다.
    
뭐 이번에 작성한 코드가 그렇게 길지 않다.


일단 Tasking 이라는 디렉터리를 만들어 줬다.

테스킹 관련 코드는 이쪽으로 넣으려고 한다.

일단, Tasking/Task.h


```c
#ifndef __TASK_H__
#define __TASK_H__

#include <Types.h>

//SS, RSP, RFLAGS, CS, RIP.. 등등 Context
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

Definition 이 많은데 결국 생각해보면 죄다 배열의 Index고 좀더 자세히보면 다 레지스터다

배열에 때려박을때 고정적인 위치에 때려박으려고 (어셈에선 순서를 지켜줘야한다 ㅋㅋ) 정의해줬다.

그 밑으로는  Context (결국 Register 값들의 배열이다.) *아마 나중에 추가 될 것 같다.

그리고 TCB (이게 중의적일거같다. Task Control Block, Thread Control Block)

TCB엔 Cotnext, ID, Flags, 스택주소와 스택 크기가 있다.

그리고 InitTask에 대한 구현인

Tasing/Task.c 이다.

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
결국 각 맴버들 초기화 하는 함수다.

세그먼트는 커널 세그먼트를 등록하고

여러 레지스터의 초깃값을 설정한다.
 
다음 실행할 코드를 (RIP 레지스터- [PC, Program Counter]) EntryPoint로 등록한다.


그리고 대망의 ContextSwitch 함수 이 함수는 어셈블리 코드와 링킹되어있다.

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

    ;RSP를 Contextswitch 호출 이전으로 되돌림 -(ReturnAddress + RBP)
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
    ;Context->Registers를 채워버림
    add rdi, 19*8
    mov rsp, rdi
    sub rdi, 19*8

    SAVECONTEXT

.LoadContext:
    mov rsp, rsi
    LOADCONTEXT
    iretq

```

일단 첫번째 파라미터가 Null(0)이면 ShellTask라고 간주한다.

.LoadContext로 점프하고

그렇게 된다면 2번째 파라미터의 Context로 Load 하게 된다.

만약 아니라면, 현제 컨텍스트를 저장한다.

저장하고 나서 두번째 파라미터로 로드.



이로써 ContextSwitch 가 끝났다.

코드도 안길고

그렇게 복잡하지도 않지만

이것저것 일때문에 바빠서 오래걸렸다.

쉬엄 쉬엄 취미로 하는 느낌이니까

큰 걱정은 없다.



휴, 다음이 스케줄링이니까 또 달려야지.