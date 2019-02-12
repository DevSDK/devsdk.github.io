---
layout: post
title: PIC Interrupt, Interrupt Handling, Active Interrupt
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

In fact, I made today afternoon, but I wrote this article now because I've got some work related to a server.

In this time, I succeeded in PCI interrupt handling.

![Interrupt handling](/uploads/2017-07-11/OS/InterruptSuccess.png)

As you could notify about up-right, you can see the "INT" small text.

An up-next number is interrupt number and next is counter.

If you just make running, it would be increased from 00 to 99.

Interrupt number 32 is a timer interrupt.

Anyway

This time I did implement of PCI driver, connecting routine for interrupt handling of IDT, context saving before interrupt handling and restore context after the process.

The book said, nowadays we use APIC that have more functions. Also, the book said we will handle it later, so skip about APIC.

We are going to handle PIC, so we need to implement a PIC driver.

![PIC](/uploads/2017-07-11/OS/PICDriver.gif)

Above image was PIC driver diagram what we'll implement.

They separated Master and Slave, Master connected 0x20 and 0x21 and Slave connected 0xA0 and 0xA1 each other that would be PortIO Map method.

On here, We try to initialize using ICW(Initial Command Word) 

When We try to use that, We will use OCW(Operation Command Word)

[You could check detail on here](https://www.allsyllabus.com/aj/note/EEE/8086%20Microprocessor%20&%20Peripherals/unit%207/Command%20Words%20of%208259A.php#.WWTTAIjyhEY)

We will use PortIO mapping when we try to initialize. We can use the PortIO Driver which made before.

I constructed PIC directory in Driver directory and made PIC.c and PIC.c files.

The contents are:

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

The four define lines are port numbers, below define line is an interrupt routine starting vector. (System reserved 1~31, so we are gonna use more than 32)

And I use ICW, OCW.

Implementation.

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

In fact, This driver's role just pushes the Command Word using Port IO.

And the codes for Interrupt Process:

![Interrupt Process Files](/uploads/2017-07-11/OS/InterruptFiles.png)

They contain interrupt setup, interrupt handler and interrupt service routine each other.

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

It's a quite short header file. This code connected assembly code directly.

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

That used interrupt enable(sti), disable(cli) and inquiring Flag Register(pushfq).

And Interrupt Service Routine's role is context saving before calling interrupt handler and restore that context.

Context saving(Fill into the stack)

![ContextSave](/uploads/2017-07-11/OS/ContextSave.png)

And Restore the context (Pop Pop pop pop!)

(If an error code has existed, We need to process that parameter)

Interrupt Service routine's header file is below.

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

All of the Above header file content's implementation connected assembly codes. I extracted part of them because it's so huge.

```nasm
;InterruptService.asm

;...SKIP...

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

;...SKIP...

```

SAVECONTEXT and LOADCONTEX are macro to use Context saving and restoring.

[Interrupt Service Routine's assembly full Source Code](https://github.com/DevSDK/0SOS/blob/master/02_Kernel64/Source/Interrupt/InterruptService.asm)

That service routine called Handler function, that was implemented in InterruptHandler.

Before that, I move Video memory output function PrintVideoMemory into Utility/Console.h because we used that here and there.  

Interrupt Handler's header file.

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

Each other, Default Handler and Keyboard Handler.

Implementation is:

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

As you can see I made that If an exception occurs, the system would be stopped and you can check the exception number through the monitor. 

At the interrupt process, codes would return, not anymore busy waiting.

Also, Interrupt occurs information and counter display at right-up.

Now, We are going to load the interrupt service routine to IDT before we made it. 

Before IDT initialize codes right below.

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

Okay, we don't need to use Dummy Handler.

Let's connect the real thing.

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

It looks so huge but it just repeated code.

Anyway, I wrote that code and try to build and try to fix some bugs.

Launch.

It's blinking.

I wanna find why it is.

Blinking occurs when I try to active interrupt.

So my mental was exploded, and I try to take a rest.

After that i try to read the code.

I removed interrupt active code, and I try to occur Divide By Zero.

It worked.

Strange. If IDT is a problem, it shouldn't work, but it's worked.

So I check detail. I find the problem.

```c
IDT_MAX_ENTRY_COUNT * sizeof(IDT_ENTRY)
```

It should be below not above code.

```c
IDT_MAX_ENTRY_COUNT + sizeof(IDT_ENTRY)
```

So It would make 0 Exception Divide by zero, but it wouldn't make Timer Interrupt in PIC. So It shut down the system and repeated. 

I'm so proud about it is worked. Interrupt was worked and the counter was increased.  

Now, Keyboard Driver update that would use interrupt was left.

And Next is the Long-awaited SHELL!!

Thanks for reading this long story.

