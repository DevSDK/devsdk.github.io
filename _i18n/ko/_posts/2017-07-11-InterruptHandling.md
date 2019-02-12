---
layout: post
title: PIC 인터럽트, 인터럽트 핸들링, 인터럽트 활성화
date:   2017-07-11 22:34:20		
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

사실 오늘 오후쯤에 만들었는데, 잠깐 서버 작업할게 생겨서 글을 지금쯤 쓴다.

이번에는 PIC인터럽트 핸들링을 성공했다.

![인터럽트핸들링](/uploads/2017-07-11/OS/InterruptSuccess.png)

딱히, 티나진 않지만 우측 상단에 작게 INT 라고 써있다.

뒤에 바로 나오는 숫자는 인터럽트 번호, 뒤에 나오는건 카운터이다.

그냥 실행시켜두면 카운터가 00부터 99까지 계속 증가한다

32는 타이머 인터럽트.

아무튼간

이번에 해준일은 PIC드라이버 제작, IDT에 인터럽트 핸들링을 위한 루틴을 연결, 인터럽트 핸들링 하기전 문맥을 저장, 처리후 복원하는 것을 다뤘다.

우선 최근에는 더 많은 기능을 제공하는 APIC를 사용한다고 한다. 책에서는 나중에 다룬다고 하니 일단 패스.

그래서 그냥 PIC를 다루는데, 이제 PIC라고 하는 것의 드라이버를 작성해야 한다.

![PIC](/uploads/2017-07-11/OS/PICDriver.gif)

작성할 PIC 드라이버의 다이어그램이다.

마스터와 슬레이브로 나뉘어있고, 각각  PortIO Map 방식으로 마스터는 0x20, 0x21 슬레이브는 0xA0, 0xA1로 연결되어있다.

여기서, ICW (Initalize Command Word)로 초기화를 해주고

사용할때는 OCW (Operation Command Word)로 사용한다.

[이곳 그림 참고](https://www.allsyllabus.com/aj/note/EEE/8086%20Microprocessor%20&%20Peripherals/unit%207/Command%20Words%20of%208259A.php#.WWTTAIjyhEY)

초기화 할때는 Port IO Mapping을 사용한다. 저번에 만들었던 Port IO 드라이버를 쓰면 되겠다.

Driver 디렉토리에 PIC 디렉토리를 만들고, PIC.h, PIC.c를 만들었다.

내용은 다음과 같다.

```c
//PIC.h

#ifndef __PIC_H__
#define __PIC_H__
#include <Types.h>

#define PIC_MASTER_PORT_1   0x20
#define PIC_MASTER_PORT_2   0x21

#define PIC_SLAVE_PORT_1    0xA0
#define PIC_SLAVE_PORT_2    0xA1

#define PIC_IRQ_VECTOR      0x20

void InitializePIC();
void MaskPICInterrupt(WORD _IRQ_Mask);
void SendPIC_EOI(int _IRQ_Number);

#endif /* __PIC_H__ */

```

위에서 4개는 포트 번호, 아래는 Interrupt 루틴의 시작 벡터 (시스템 예외로 예약된 31번까지를 제외하고 32부터 사용한다.)

그리고 ICW, OCW를 이용해 함수를 만들었다.

그 구현

```c
//PIC.c
#include "PIC.h"
#include <Driver/IO/PortIO.h>

void InitializePIC()
{

    //Initalize Master PIC
    //ICW1 IC4 = 1
    PortIO_OutByte(PIC_MASTER_PORT_1, 0x11);
    //ICW2 Interrupt Vector Offset = 0x20 (32)
    PortIO_OutByte(PIC_MASTER_PORT_2, PIC_IRQ_VECTOR);
    //ICW3 Master-Slave Pin S2=1   |  0x04
    PortIO_OutByte(PIC_MASTER_PORT_2, 0x04);
    //ICW4 SFNM = 0 BUF = 0 M/S = 0 AEOI = 0 uPM = 1 
    PortIO_OutByte(PIC_MASTER_PORT_2, 0x01);
    
    //Initalize Slave PIC
    //ICW1 IC4 = 1
    PortIO_OutByte(PIC_SLAVE_PORT_1, 0x11);
    //ICW2 Interrupt Vector Offset = 0x28
    PortIO_OutByte(PIC_SLAVE_PORT_2, PIC_IRQ_VECTOR + 8);
    //ICW3 Master-Slave Pin Number = 2 | 0x2
    PortIO_OutByte(PIC_SLAVE_PORT_2, 0x02);
    //ICW4 SFNM = 0 BUF = 0 M/S = 0 AEOI = 0 uPM = 1
    PortIO_OutByte(PIC_SLAVE_PORT_2, 0x01);


}   

void MaskPICInterrupt(WORD _IRQ_Mask)
{
    //OCW1 IRQ0~IRQ7
    PortIO_OutByte(PIC_MASTER_PORT_2, _IRQ_Mask);
    //OCW1 IRQ8~IRQ15
    PortIO_OutByte(PIC_SLAVE_PORT_2 , (BYTE)(_IRQ_Mask>>8));
}

void SendPIC_EOI(int _IRQ_Number)
{
    //OCW2 NonSpecific EOI Command.
    PortIO_OutByte(PIC_MASTER_PORT_1, 0X20);

    //If Slave Interrupt.
    if(_IRQ_Number>=8)
    {
        PortIO_OutByte(PIC_SLAVE_PORT_1, 0x20);
    }
}
```

사실, Port IO를 이용해 계속 Command Word 를 날리는게 이 드라이버의 역할이다.

그리고 인터럽트 처리를 위한 코드들

![인터럽트 처리 파일](/uploads/2017-07-11/OS/InterruptFiles.png)

각각 인터럽트 설정, 인터럽트 핸들러, 인터럽트 서비스 루틴이 들어있다.


```c
//Interrupt.h

#ifndef __INTERRUPT_H__
#define __INTERRUPT_H__
#include <Types.h>
void EnableInterrupt();
void DisableInterrupt();
QWORD ReadFlags();
#endif /*__INTERRUPT_H__*/
``` 

이런 짧은 해더파일이다. 이 코드는 어셈블리 코드랑 직접 연결된다.

```nasm
;Interrupt.asm
[BITS 64]

SECTION .text

global EnableInterrupt, DisableInterrupt, ReadFlags

EnableInterrupt:
    sti
    ret
DisableInterrupt:
    cli
    ret
ReadFlags:
    pushfq
    pop rax
    ret
``` 
인터럽트를 활성화(sti), 비활성화(cli), Flag 레지스터 조회(pushfq)
에 사용된다.


그리고 인터럽트 서비스 루틴

인터럽트 서비스 루틴은, 인터럽트 핸들러를 호출하기 전 


Context의 보관(스택에 싹 집어넣기)

![ContextSave](/uploads/2017-07-11/OS/ContextSave.png)

후, Cotext 복원 (pop pop pop pop!!)

(Error Code가 있을경우 파라미터 처리)

후 다시 스택 스위칭하고 원래 코드로 복귀하는 역할을 한다.

인터럽트 서비스 루틴의 해더파일은 다음과 같다.
```c
//InterService.h
#ifndef __INTERRUPT_SERVICE_H__
#define __INTERRUPT_SERVICE_H__

//Reserved Exceptions
void ISRDividError();
void ISRDebug();
void ISRNMI();
void ISRBreakPoint();
void ISROverflow();
void ISRBoundRangeExceeded();
void ISRInvalidOpCode();
void ISRDeviceNotAvailable();
void ISRDoubleFault();
void ISRCoProcessorSegmentOverrun();
void ISRInvalidTSS();
void ISRSegmentNotPresent();
void ISRStackSegmentFault();
void ISRGeneralProtection();
void ISRPageFault();
void ISR15();
void ISRFloatingPointError();
void ISRAlignmentCheck();
void ISRMachineCheck();
void ISRSIMDError();
void ISRDefaultException();
//PIC Interrupt
void ISRTimer();
void ISRPS2Keyboard();
void ISRSlavePIC();
void ISRSerialPort2();
void ISRSerialPort1();
void ISRParallel2();
void ISRFloppy();
void ISRParallel1();
void ISRRTC();
void ISRReserved();
void ISRNotUsed1();
void ISRNotUsed2();
void ISRPS2Mouse();
void ISRCoprocessor();
void ISRHDD1();
void ISRHDD2();
void ISRDefaultInterrupt();
#endif /* __INTERRUPT_SERVICE_H__ */
```

위 해더파일은 전부 어셈블리 구현으로 연결되며, 코드가 너무 길어서 일부만 가져왔다.

```nasm
;InterruptService.asm

;...생략...

ISRDividError:
    SAVECONTEXT
    mov rdi, 0
    call DefaultExceptionHandler
    LOADCONTEXT
    iretq
ISRDebug:
    SAVECONTEXT
    mov rdi, 1
    call DefaultExceptionHandler
    LOADCONTEXT
    iretq
ISRNMI:
    SAVECONTEXT
    mov rdi, 2
    call DefaultExceptionHandler
    LOADCONTEXT
    iretq
ISRBreakPoint:
    SAVECONTEXT
    mov rdi, 3
    call DefaultExceptionHandler
    LOADCONTEXT
    iretq
ISROverflow:
    SAVECONTEXT
    mov rdi, 4
    call DefaultExceptionHandler
    LOADCONTEXT
    iretq

;...생략...

```

SAVECONTEXT
LOADCONTEX는 각각 Contex를 보관,복귀 할때 쓰는 코드의 메크로.

[인터럽트 서비스 루틴 어셈블리 Full Source Code](https://github.com/DevSDK/0SOS/blob/master/02_Kernel64/Source/Interrupt/InterruptService.asm)


저 서비스 루틴은 Handler함수를 호출하게 되는데,

InterruptHandler 에 구현이 되어있다.

그 전에, 이번에 비디오메모리에 출력하는 함수를 이파일 저파일에서 사용하게 되서 Utility/Console.h 에 PrintVideoMemory를 옮겼다.


인터럽트 핸들러의 해더파일이다.

```c
//InterruptHandler.h

#ifndef __INTERRUPT_HANDLER_H__
#define __INTERRUPT_HANDLER_H__

#include <Types.h>

void DefaultExceptionHandler(int _Vector, QWORD _ErrorCode);
void DefaultInterruptHandler(int _Vector);
void KeyboardInterruptHandler(int _Vector);

#endif /*__INTERRUPT_HANDLER_H__*/

```

각각, 기본 핸들러, 키보드 핸들러다.


구현은 다음과 같다.

```c
//InterruptHandler.c
#include "InterruptHandler.h"
#include <Driver/PIC/PIC.h>
#include <Utility/Console.h>
void __DebugIntOutput(int _Vector, int _Count)
{
    char Buffer[] = "[INT:  ,  ]";
    Buffer[5] = _Vector/10 + '0';
    Buffer[6] = _Vector%10 + '0';
    Buffer[8] = _Count/10  + '0';
    Buffer[9] = _Count%10  + '0';  
    PrintVideoMemory(69,0,0x0F,Buffer);
}

void DefaultExceptionHandler(int _Vector, QWORD _ErrorCode)
{
    char Buffer[3] = {0,};
    Buffer[0] = '0' + _Vector/10;
    Buffer[1] = '0' + _Vector%10;
    PrintVideoMemory(0,0,0xF,"================================================================================");
    PrintVideoMemory(0,1,0xF,"Exception:                                                                      ");
    PrintVideoMemory(0,2,0xF,"                                                                                ");
    PrintVideoMemory(0,3,0xF,"================================================================================");
    PrintVideoMemory(11,1,0xF, Buffer);

    while(1);
}
void DefaultInterruptHandler(int _Vector)
{
    
    static int g_DefaultInterruptCounter = 0;

    g_DefaultInterruptCounter = (g_DefaultInterruptCounter + 1)%100;
    __DebugIntOutput(_Vector, g_DefaultInterruptCounter);
    SendPIC_EOI(_Vector - PIC_IRQ_VECTOR);
}
void KeyboardInterruptHandler(int _Vector)
{
    
    static int g_KeyboardInterruptCounter = 0;

    g_KeyboardInterruptCounter = (g_KeyboardInterruptCounter + 1)%100;
    __DebugIntOutput(_Vector, g_KeyboardInterruptCounter);
    SendPIC_EOI(_Vector - PIC_IRQ_VECTOR);
}
```

내용을 보면 예외가 발생하면 일단, 시스템을 정지시키고 예외 번호를 보여주게 만들어뒀고,

인터럽트 처리구믄을 보면 더이상 멈춰있지않고 반환을 한다.

또한, 인터럽트 발생정보와, 발생횟수를 우측 상단에 출력한다!


이제, 아까 만들었던 인터럽트 서비스 루틴을

저번에 열씸히 만든 IDT에 싹 올려놓으면 된다.

저번의 IDT 초기화 구문은 이랬다.


```c
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
```

이제, 더미 핸들러는 버리고

실제로 동작하는 핸들러와 잇는다.

```c
//IDT.c

void InitializeIDTTables()
{
    IDTR* idtr = (IDTR*) IDTR_POINTER;
    IDT_ENTRY* entry =  (IDT_ENTRY*)(IDTR_POINTER + sizeof(IDTR));
    
    idtr->BaseAddress   = (QWORD)entry;
    idtr->Size          = IDT_TABLE_SIZE - 1;

    SetIDTEntry(&entry[0],ISRDividError,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[1],ISRDebug,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[2],ISRNMI,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[3],ISRBreakPoint,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[4],ISROverflow,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[5],ISRBoundRangeExceeded,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[6],ISRInvalidOpCode,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[7],ISRDeviceNotAvailable,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[8],ISRDoubleFault,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[9],ISRCoProcessorSegmentOverrun,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[10],ISRInvalidTSS,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[11],ISRSegmentNotPresent,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[12],ISRStackSegmentFault,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[13],ISRGeneralProtection,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[14],ISRPageFault,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[15],ISR15,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[16],ISRFloatingPointError,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[17],ISRAlignmentCheck,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[18],ISRMachineCheck,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[19],ISRSIMDError,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[20],ISRDefaultException,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);

    for(int i= 21; i < 32 ; i++)
    {
        SetIDTEntry(&entry[i],ISRDefaultException,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    }

    SetIDTEntry(&entry[32],ISRTimer,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[33],ISRPS2Keyboard,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[34],ISRSlavePIC,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[35],ISRSerialPort2,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[36],ISRSerialPort1,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[37],ISRParallel2,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[38],ISRFloppy,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[39],ISRParallel1,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[40],ISRRTC,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[41],ISRReserved,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[42],ISRNotUsed1,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[43],ISRNotUsed2,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[44],ISRPS2Mouse,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[45],ISRCoprocessor,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[46],ISRHDD1,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    SetIDTEntry(&entry[47],ISRHDD2,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    
    for(int i = 48; i < IDT_MAX_ENTRY_COUNT; i++)
    {
        SetIDTEntry(&entry[i],ISRDefaultInterrupt,0x08, IDT_ENTRY_IST1, IDT_ENTRY_KERNEL, IDT_TYPE_INTERRUPT);
    }
}

```
뭔가 많은데, 반복되는 코드일 뿐이다.

저번에 더미 코드로 이어주었던 이 코드를 아까 만든 서비스루틴하고 이은것이다.




아무튼 위 코드를 작성하고 빌드하고, 자잘한 버그 고치고

실행


깜빡거린다 흠... 

왜 그런지 찾아보고 찾아봤다.

일단 깜빡거리는게 발생하는건 

인터럽트를 활성화 할때였다.

1차 멘붕오고 다시 멘탈 잡고 코드를 자세히 봤다.

인터럽트 활성화 코드를 잠깐 빼고, Divide By Zero 예외를 발생시켰는데

동작한다.


이상하다. IDT 자체가 이상하면 둘다 안됬어야 하는데, 이상하게 일부만 동작한다.

그래서 좀더 자세하게 코드를 보니
```c
IDT_MAX_ENTRY_COUNT * sizeof(IDT_ENTRY)
```
여야 할 코드가

```c
IDT_MAX_ENTRY_COUNT + sizeof(IDT_ENTRY)
```
로 되어있었다. 이러니까, 0번 익셉션인 Divide By Zero 는 먹히고

PIC의 Timer Interrupt 처리는 못해서 시스템이 다운되고 켜지고 반복했던거다.


해결해서 인터럽트가 동작하고, 카운터 올라가는 모습을 보니 뿌듯하다.


이제 인터럽트 방식으로 키보드 처리하게끔 키보드 드라이버를 업데이트 하는 일이 남았다.

그다음은 드디어 쉘!


이 길고 긴 글 읽어주셔서 고맙다고 인사를 드리고 싶다.

