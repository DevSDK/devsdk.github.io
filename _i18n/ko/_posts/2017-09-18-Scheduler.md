---
layout: post
title: 라운드 로빈 스케줄러와 시분할 ContextSwitching
date:   2017-09-18 22:46:20		
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
- Scheduling
- MultiCore
- 64bit
---		

SW 마에스트로 일이 바쁘다 보니 개발 틈틈히 개발해 지금 완성했다.

사실 좀 논것도 있지만.

이번에 개발한 양이라던가, 생각할게 좀 많아서 시간이 걸리기도 했다.

아무튼 이번에 개발한 부분은 MultiTasking을 위한 Round Robin Scheduler 구현과

IRQ0 TimerInterrupt를 이용한 시분할 스케줄링의 구현이다.

구현되서 동작하는 모습이다. 셸과는 별개로 저 글자가 움직인다.(동시에 움직인다).

![동작함!](/uploads/2017-09-18/0SOS/TaskWork.png)

MultiLevel이 아니기 때문에 일단, 모든 Task는 5ms의 CPU 시간을 가질 수 있다고 지정했다.

위키백과의 말을 빌려 스케줄링이란 다중 프로그래밍이 가능하게 해주는 OS의 동작 기법이라고 한다.

뭐 대충 요약하자면 말그대로 여러 Task를 동시에 쓰는거처럼 만들고 싶은거다.

그 기법도 다양하다 FCFS, SJF ... 등등 많인데, 그중에 Round Robin 기법을 사용할 것이다.

우선순위는 고려하지 않고 일단 같은 CPU 시간을 부여하는 방식이다. 뭐, 나중에 멀티레벨 큐를 구성하면

우선순위를 적용 시킬 수 있을것이라고 생각한다.

이것도 고려해야할게 생각보다 많다.

일단 데이터가 (테스크가) 수시로 추가 및 제거가 될것이기 때문에 배열기반 자료구조 보단

연결리스트 기반의 자료구조를 구성한다.

따라서 먼저 Linked List를 구현했다.

네이밍이 좀 구린거 같긴한데 딱히 다른거 안떠올라서 LinkedList라 LList로 짧게 만들었다.

LList는 범용 자료구조에 속해서 /GDS/ 디렉터리 안에 구현했다.

다음은 LList의 해더파일이다.

node에 list 해더를 심게끔 만들어서 범용성을 좀더 꾀해보려고 했다.


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
    exmple of element data structure.

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
Example 구조체처럼 데이터 노드에 해당하는 구조체 앞에 LLIST_NODE_HEADER를 정의해줘야한다.

Linked List를 굳이 길게 이야기 할 필요는 없어보인다.

다음은 /GDS/LinkedList.c의 내용이다.

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

일단 연결리스트 자체는 구현이 어렵지 않게 구현했다. 하지만 난관이 하나 있다.

바로 0SOS엔 Heap Allocator가 없단것. 즉, 동적 할당이 불가능하다.

이걸 해결하고, 효율적으로 메모리를 관리하기 위해서 TCB Pooling을 사용하기로 한다.

(정적으로 특정 영역을 지정해두고, 이 부분을 케이크처럼 잘라서 할당해주는것.)

8MB 이후 영역부터 TCB Pool 그리고, TCB Pool 위에 TaskStackPool을 구성하도록 한다.

대충 그림으로 표현하자면.


![MemoryMap](/uploads/2017-09-18/0SOS/MemoryMap.png)

OneNote로 그렸는데 흠... 괜찮나

아무튼 다음과 같은 구조를 가지게 된다.

(8MB이후 영역 크기 계산이 귀찮아서 그냥 대충 저렇게 표현했다)

여기서 2MB영억부터  0x205C19까지는 64비트(IA-32e모드)커널 영역이다.

![Instruction](/uploads/2017-09-18/0SOS/InstructionLast.png)



아, 그리고 책에선 ID부분을 32비트 32비트로 나눠서 앞의 32비트 영역이 0이 아니면 할당되었다

이런식으로 처리하길레 내 마음에 들게 고쳤다.

앞0비트부터 55비트까진 ID의 Index 뒤 56비트부터 63비트까진 Status를 나타내는 비트로 정의했다

그림으로 나타내면 다음과 같다.

![TCBID](/uploads/2017-09-18/0SOS/TCBID.png)

그렇게 Task.h와 Task.c에 내용을 추가했다.

다음은 Tasking/Task.h 내용이다.


```c
#ifndef __TASK_H__
#define __TASK_H__

#include <Types.h>
#include <GDS/LinkedList.h>
//SS, RSP, RFLAGS, CS, RIP.. 등등 Context
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

//Include Linked List Header.
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
AllocateTCB,FreeTCB, InitializeTCB 등등의 함수와 TCB_POOL_MANAGER 등등의 구조체를 정의했다.

그리고 TCB ID를 위한 MASK.

다음은 c코드이다.

```c
#include "Task.h"
#include <Utility/Memory.h>
#include <Descriptor/GDT.h>
#include <Console/Console.h>

static TCB_POOL_MANAGER g_TcbPoolManager;

void InitTask(TCB* _Tcb, QWORD _Flags, QWORD _EntryPointAddress, void* _StackAddress, QWORD _StackSize)
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
    _Tcb->StackAddress  = _StackAddress;
    _Tcb->StackSize     = _StackSize;
    _Tcb->Flags         = _Flags;
 }

 void InitializeTCBPool()
 {
     //8MB부터 시작되는 Task Pool 영역 초기화 및 Mananger 초기화
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
    //TCBPool이 가득 찼다면 NULL을 반환  
    if(g_TcbPoolManager.Count == g_TcbPoolManager.MaxCount)
        return NULL;
    //Free 상태인 TCB를 TCBPool에서 선형탐색
    for(int i = 0; i < g_TcbPoolManager.MaxCount; i++)
    {
        if((g_TcbPoolManager.StartAddress[i].list_header.ID & TASK_STATE_MASK) == TASK_FREE )
        {
            EmptyTCB = &(g_TcbPoolManager.StartAddress[i]);
            break;
        }
    }
    //Allocate Count를 이용하여 ID값을 만듬 또한 TASK_ALLOCATED를 or 해서 ALOCATOED 상태로 전환함
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
    //_ID에서 Index 부분만 추출
    QWORD index = _ID & TASK_INDEX_MASK;
    //TCB Context 초기화
    _MemSet(&(g_TcbPoolManager.StartAddress[index].Context), 0, sizeof(CONTEXT));
    //할당 해제
    g_TcbPoolManager.StartAddress[index].list_header.ID = index;
    g_TcbPoolManager.Count--;
}
TCB* CreateTask(QWORD _Flags, QWORD _EntryPointAddress)
{
    TCB* task = AllocateTCB();

    if(task == NULL)
        return NULL;
    //스택 어드레스를 구함. TCBPool이 끝나는 주소가 시작주소 + STACKSIZE * INDEX
    void* StackAddress = (void*)(TASK_STACK_ADRESS + 
        (TASK_STACK_SIZE * (task->list_header.ID & TASK_INDEX_MASK)));
    
    InitTask(task,  _Flags, _EntryPointAddress, StackAddress, TASK_STACK_SIZE);
    
    //스케줄러에 등록
    AddTaskToScheduler(task);
    return task;
}
 
```

구체적인 설명은 위에서 했기때문에, 생략하겠다.

이제 가장 핵심인 스케줄러 코드다.


뭐랄까, 생각보다 크게 특별한 내용은 없다.


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

해더파일이다. 스케줄링을 위한 여러 함수와 초기화 함수, Round Robin Scheduling을 위한 

최대 CPU 사용시간을 지정해준다.

그냥 코드에서 Schedule 함수가 호출됬을때랑

IRQ0 TimerInterrupt에서 호출됬을때 ContextSwitching 기법이 약간 다르다.

코드에서 Schedule 하는건 그냥 ContextSwitch 하면 되지만, Interrupt때는

IST에 있는 Context 변경해주면서 Context를 지정해주어야한다.

이걸 그림으로 그리려했으나 표현력이 딸려서... ( 젠장 )

좀더 쉽게말하면 Interrupt 에 쓰이는 IST 영역에 Context가 저장되니까 그걸 변경하면 Interrupt 종료시 자동으로 

Contxt Switch가 된다는 이야기.

소스코드로 보자.

```c
#include "Scheduler.h"
#include <Tasking/Task.h>
#include <Interrupt/Interrupt.h>
#include <Descriptor/IDT.h>
#include <Utility/Memory.h>
#include <Console/Console.h>
static SCHEDULER g_Scheduler;
//TCBPool 초기화 및 TaskList초기화
void InitializeScheduler()
{
    InitializeTCBPool();
    InitializeLList(&(g_Scheduler.task_list));
    //Shell Task를 현제 Task로 지정함
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
    //스케줄링 리스트가 비어있다면 반환함
    if(g_Scheduler.task_list.Count == 0)
        return;

    //인터럽트 비활성화
    BOOL interrupt_status = SetInterruptFlag(FALSE);
    TCB* task = GetNextTask(); 
    //다음 Task가 NULL이라면
    if(task == NULL)
    {
        //Interrupt를 복구하고 반환
        SetInterruptFlag(interrupt_status);
        return;
    }
    //현제 테스크를 스케줄링 리스트에 등록
    TCB* pre_task = g_Scheduler.Current_Runing_Task;
    AddTaskToScheduler(pre_task);   
    
    //현제 수행중인 Task 변경
    g_Scheduler.Current_Runing_Task = task;
    //Context Switch
    ContextSwitch(&(pre_task->Context), &(task->Context));
    //Cputime 초기화
    g_Scheduler.CpuTime = TASK_TIME;
    //인터럽트 복구
    SetInterruptFlag(interrupt_status);

}
//인터럽트에 의해 호출됨
BOOL ScheduleInInterrupt()
{
    //다음 테스크를 가져옴
    TCB* task = GetNextTask();
    if(task == NULL)
    {
        return FALSE;
    }

    
    //IST STACK에 저장된 CONTEXT ADDRESS
    void* ContextAddress = IST_POINTER + IST_SIZE - sizeof(CONTEXT);
    
    TCB* running_task = g_Scheduler.Current_Runing_Task;
    //CONTEXT 저장
    _MemCpy(&(running_task->Context), ContextAddress, sizeof(CONTEXT));
    g_Scheduler.Current_Runing_Task = task;
    AddTaskToScheduler(running_task);
    //Context 전환 후 복원
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

주석을 구체적으로 달아뒀다고 생각한다. 흠...

이제 Scheduling을 위한 준비는 끝났다.

이제 IRQ0 Timer Interrupt 와 이어서 시분할 멀티테스킹이 가능하게 해줬다.

Interrupt/InterruptHandler.c에 다음 함수를 추가했다.

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
Interrupt/InterruptService.asm 에서 IRQ0인터럽트
```nasm
ISRTimer:
    SAVECONTEXT
    mov rdi, 32
    call TimerInterruptHandler
    LOADCONTEXT
    iretq

```

이제 시분할을 위한 준비도 끝났으니, Shell 코드에 다음 내용을 추가했다.

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

대충 createtask (타입 1,2 중 하나) 개수

명령어로 task를 생성한다.

타입 2는 바람개비같은걸 만들고

타입 1은 빙글빙글 돌아다니는 글자 열? 같은거다.

바람개비는 테스크 하나당 하나를 담당한다.

아무튼, 위에는 깔끔하게 잘 동작하는 코드들일 뿐이다.

동작하게끔 하기까지 수많은 시련이 있었는데,


![Excepton7](/uploads/2017-09-18/0SOS/Exception7.png)

Exception7 이였다.


구체적인 내용은 x86 시스템에서 7코드인 "Device Not Available" 문제였다.

찾아보면 FPU관련된 문제라고들 하는데, 아직 내 OS는 FPU를 제공하지 않으니

왜그런걸까 고민해봤다.


잘 찾아보니까 이럴수가

Task.h 에서 범용 레지스터 개수는 24개인데 DEFINE에는 25개로 정의해버렸다.

고치고 난뒤, 이번엔 Exception 14 Page Falult가 뜬다.

찾아보고 메모리 뜯어보니까 연결리스트가 문제였다.

고치고 나니까, 멀정해졌다.

뭐, 디버깅 과정에서 메모리 맵 뜯고 난리 쳣지만

결론적으론, 함수호출 하나 잘못한거랑 링크드 리스트 문제가 있었다는거 말곤 없어서

구체적으로 쓰진 않겠다.



휴, 드디어 멀티테스킹이 동작한다.

이제 이 프로젝트는 잠깐 동결될 듯 하다.

소프트웨어 마에스트로 프로젝트를 진행해야해서 아마 내년 1월달에나 재개되지 않을까 싶은데,

소마에서 하는 프로젝트도 LinuxKernel 기반의 운영체제니 뭐...

시간 봐서 종종 일지 올리겠다.


