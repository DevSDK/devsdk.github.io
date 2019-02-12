---
layout: post
title:     Implemented timer driver.
date:   2017-08-03 11:11:20        
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
- Timer
- Interrupt
- 64bit
---

Finally, I've got time for OS developing.

I'm so busy so I can't make time.

Actually, I wrote code quite a bit with my laptop but it wasn't a huge change.
So I didn't write an article.

Before the article, the following is changing.

Changed BOOL type unsigned char to c99 _Bool type in Types.h 

The reason why is little bit complicate.

One of the reason is ! operator to unsigned char.

Usually, When we try to not operation, we can faster if we use x xor 1.

But I found different! operation between unsigned char and x xor 1. 

![UC_NotOp](/uploads/2017-08-03/OS/UC_NOT.png)


![UC_XorOp](/uploads/2017-08-03/OS/UC_XOR.png)

It is definitely different.

If I use compiler optimize option like -O3, it will be changed to xor. But It can be worked to un-properly.

When I don't use compiler optimize option, not operation's instructions are more than xor.

After cmp instruction, data was set through setne instruction. Because System thought it can use other bits not only t/f bit.

So It has been solved by changing unsigned char to _Bool.

---

Yeah, here we are the main topic.

This time I've developed a timer.

Specifically, I made PIT(Programmable Interval Timer) Driver, Timestamp and RTC(Real Time Clock) Driver.

Below image is source tree.

![SourceTree](/uploads/2017-08-03/OS/TimeTree.png)


We can access PIT through PortIO Driver at 0x43, 0x40, 0x41 and 0x42.

Well, It needs to setup many bits. 

7,6 - SC : Select Counter  for a target of a command 

5,4 - RW : Read/Write

        00: Read the current value of the counter (2byte)

        01: R/W counter low bytes (1Byte)

        10: R/W counter high bytes (1Byte)

        11: R/W low to a high byte in counter(2Byte)

3,2,1-Mode: Set up PIT controller count mode 

        000: Mode 0 (Interrupt during counting)

        001: Mode 1 (Programmable monoflop)

        010: Mode 2 (Clock rate generator)

        011: Mode 3 (Square wave generator)

        100: Mode 4 (Software-triggered impulse)

        101: Mode 5 (Hardware-triggered impulse)

0   - BCD : Setup counter to binary or BCD format.

        BCD format until 0~9999 

        Binary format until 0x00~0xFFFF 


Anyway, that would be selected by SC field, below things are options.

sDriver/Time/PIT.h 
 
```c
#ifndef __PIT_H__
#define __PIT_H__

#include <Types.h>
//PIT frequency 1.193182MHz 
#define PIT_FREQUENCY 1193182

#define MS_TO_COUNT(x) (PIT_FREQUENCY * (x)/1000)
#define US_TO_COUNT(x) (PIT_FREQUENCY * (x)/1000000)

#define PIT_PORT_CONTROL    0x43
#define PIT_PORT_COUNTER0   0x40
#define PIT_PORT_COUNTER1   0x41
#define PIT_PORT_COUNTER2   0x42

#define PIT_CONTROL_SC_COUNTER0   0x00
#define PIT_CONTROL_SC_COUNTER1   0x40
#define PIT_CONTROL_SC_COUNTER2   0x80

#define PIT_CONTROL_RW_BIT11      0x30
#define PIT_CONTROL_RW_BIT00      0x00

#define PIT_CONTROL_MODE_0        0x00
#define PIT_CONTROL_MODE_2        0x04

#define PIT_CONTROL_BCD_FALSE     0x00
#define PIT_CONTROL_BCD_TRUE      0x01

#define PIT_COUNTER0_FLAG_ONCE  (PIT_CONTROL_SC_COUNTER0 | PIT_CONTROL_RW_BIT11 | PIT_CONTROL_MODE_0 | PIT_CONTROL_BCD_FALSE)
#define PIT_COUNTER0_FLAG_INTERVAL  (PIT_CONTROL_SC_COUNTER0 | PIT_CONTROL_RW_BIT11 | PIT_CONTROL_MODE_2 | PIT_CONTROL_BCD_FALSE)
#define PIT_COUNTER0_FLAG_LATCH  (PIT_CONTROL_SC_COUNTER0 | PIT_CONTROL_RW_BIT00 )




// SET PIT Counter 0 = _Count and Cange state Interval
void InitializePIT(WORD _Count, BOOL _IsInterval);

WORD ReadTimerCount0();


/*
    Should be disable Interrupt
    Parameter _Count : < 50ms
*/

void WaitUsingPITCounter0(WORD _Count);



#endif /*__PIT_H__*/
```

PIT works on 1.19318 Mhz, decreasing counter value every single time to 0. If the counter value is 0, it would make a signal.

We need to convert that PIC to time we use, we take formula t = 1193182 * rate ( ex: 1ms rate = 0.001 )

0SOS is going to use counter 0 and the book said counter 1 and 2 are usually used main memory and speaker.

It'll be implemented by PortMapIO data read/write.

```c
#include "PIT.h"
#include <Driver/IO/PortIO.h>

void InitializePIT(WORD _Count, BOOL _IsInterval)
{
    //If it has interval, it would be mode 2. If not, mode 0.
    if(_IsInterval == TRUE)
        PortIO_OutByte(PIT_PORT_CONTROL, PIT_COUNTER0_FLAG_INTERVAL);
    else
        PortIO_OutByte(PIT_PORT_CONTROL, PIT_COUNTER0_FLAG_ONCE);
    //Set up upper bits and lower bits
    PortIO_OutByte(PIT_PORT_COUNTER0, _Count);
    PortIO_OutByte(PIT_PORT_COUNTER0, _Count >> 8);
}

WORD ReadTimerCount0()
{
    BYTE high, low;
    WORD ret = 0x0000;
    //Read data of Counter 0.
    PortIO_OutByte(PIT_PORT_CONTROL, PIT_COUNTER0_FLAG_LATCH);
    low = PortIO_InByte(PIT_PORT_COUNTER0);
    high = PortIO_InByte(PIT_PORT_COUNTER0);
    //Transfer 2 byte using upper and lower bits.
    ret = high;
    ret = (ret << 8) | low;
    return ret;
}

void WaitUsingPITCounter0(WORD _Count)
{
    //Repeat 0~0xFFFF area.

    WORD CurrentCounter = 0;
    InitializePIT(0, TRUE);
    const WORD LastCounter0 = ReadTimerCount0();
    while(TRUE)
    {
        //Get Counter 0 Value
        CurrentCounter = ReadTimerCount0();
        //Value is incresed by time spent.  
        if(((LastCounter0 - CurrentCounter) & 0xFFFF) >= _Count)
            break;    
    }

}
```

Initialize PIT function and read the counter 0 function and waiting for function by millisecond

Next is a time stamp.

The time stamp would be increased by clock and bus speed.

So We can measure more detail of time. 

```nasm
;Driver/Time/TSC.asm
[BITS 64]

SECTION .text

global ReadTSC

;Return read value of time stamp counter.
ReadTSC:
    push rdx
    rdtsc   ;Save time stamp counter value in rdx:rax.
    shl rdx, 32
    or rax, rdx ; upper 32bit tcs value of rdx register and lower tsc value of rax register to rax.
    pop rdx
    ret
```

Load by RDTSC command.

And next is RTC driver.

RTC controller works for memorizing time. Also, it still works after off your PC. 

RTC data stored in CMOS memory. We should get RTC value to access CMOS.

CMOS memory can be access by PortIO Driver, using memory address port 0x70 and data port 0x71.

Table of RTC.

![CMOSMemory](/uploads/2017-08-03/OS/CMOSField.png)


```c
//Driver/Time/RTC.h
#ifndef __RTC_H__
#define __RTC_H__
#include <Types.h>

#define  PORT_CMOS_ADDRESS      0x70
#define  PORT_CMOS_DATA         0x71

#define  CMOS_ADDRESS_RTC_SECOND       0x00
#define  CMOS_ADDRESS_RTC_MINUTE        0x02
#define  CMOS_ADDRESS_RTC_HOUR          0x04
#define  CMOS_ADDRESS_RTC_DAY_OF_WEEK   0x06
#define  CMOS_ADDRESS_RTC_DAY_OF_MONTH  0x07
#define  CMOS_ADDRESS_RTC_MONTH         0x08
#define  CMOS_ADDRESS_RTC_YEAR          0x09

//Changing BCD code. 
#define  BCD_TO_BIN(x) ((((x) >> 4) * 10) + ((x)  & 0x0F ))
void ReadRTCTime(BYTE* _Out_Hour, BYTE* _Out_Minute, BYTE* _Out_Second);
void ReadRTCDate(WORD* _Out_Year, BYTE* _Out_Month, BYTE* _Out_DayOfMonth, BYTE* _Out_DayOfWeek);
char* ConvertDayOfWeekString(BYTE _DayOfWeek);

#endif /*__RTC_H__*/
```

Defining the address field and getting data and changing the date to string is this code's role. 

And RTC data from CMOS should transfer BCD code to binary.

```c
//Driver/Time/RTC.c
#include "RTC.h"

void ReadRTCTime(BYTE* _Out_Hour, BYTE* _Out_Minute, BYTE* _Out_Second)
{
    BYTE data;
    //Time data from CMOS memory is BCD code.
    PortIO_OutByte(PORT_CMOS_ADDRESS, CMOS_ADDRESS_RTC_HOUR);
    data = PortIO_InByte(PORT_CMOS_DATA);
    *_Out_Hour = BCD_TO_BIN(data);

    PortIO_OutByte(PORT_CMOS_ADDRESS, CMOS_ADDRESS_RTC_MINUTE);
    data = PortIO_InByte(PORT_CMOS_DATA);
    *_Out_Minute = BCD_TO_BIN(data);

    PortIO_OutByte(PORT_CMOS_ADDRESS, CMOS_ADDRESS_RTC_SECOND);
    data = PortIO_InByte(PORT_CMOS_DATA);
    *_Out_Second = BCD_TO_BIN(data);    
}
void ReadRTCDate(WORD* _Out_Year, BYTE* _Out_Month, BYTE* _Out_DayOfMonth, BYTE* _Out_DayOfWeek)
{
    BYTE data;
    //Time data from CMOS memory is BCD code.
    PortIO_OutByte(PORT_CMOS_ADDRESS, CMOS_ADDRESS_RTC_YEAR);
    data = PortIO_InByte(PORT_CMOS_DATA);
    *_Out_Year = BCD_TO_BIN(data) + 2000; //연도에 2000을 더해 2000년도를 표현

    PortIO_OutByte(PORT_CMOS_ADDRESS, CMOS_ADDRESS_RTC_MONTH);
    data = PortIO_InByte(PORT_CMOS_DATA);
    *_Out_Month = BCD_TO_BIN(data);

    PortIO_OutByte(PORT_CMOS_ADDRESS, CMOS_ADDRESS_RTC_DAY_OF_MONTH);
    data = PortIO_InByte(PORT_CMOS_DATA);
    *_Out_DayOfMonth = BCD_TO_BIN(data);
    
    PortIO_OutByte(PORT_CMOS_ADDRESS, CMOS_ADDRESS_RTC_DAY_OF_WEEK);
    data = PortIO_InByte(PORT_CMOS_DATA);
    *_Out_DayOfWeek = BCD_TO_BIN(data);    
}
char* ConvertDayOfWeekString(BYTE _DayOfWeek)
{
    //weekdate to string
    static char* WeekStringTable [8] = {"NULL", "Sunday", "Monday", "Tushday", "Wednesday", "Thursday", "Friday", "Saturday"};

    if(_DayOfWeek >= 8)
        return WeekStringTable[0];

    return WeekStringTable[_DayOfWeek];
```

Timer driver is completed by this!

So We can use this driver in the shell command.

```c


void Command_SetTimer(const char* _Parameter)
{
    char ParameterBuffer[200];
    PARAMETERLIST pList;
    InitializeParameter(&pList, _Parameter);

    if(GetNextParameter(&pList,ParameterBuffer) == 0)
    {
        _Printf("settimer {time(ms)} {interval}\n");
        return;
    }
    long value;
    if(_atoi(ParameterBuffer, &value, 10) == FALSE)
    {
        _Printf("Parameter Decimal number\n");
        return;
    }

    if(GetNextParameter(&pList,ParameterBuffer) == 0)
    {
        _Printf("settimer {time(ms)} {interval}\n");
        return;
    }

    long interval_value;
    if(_atoi(ParameterBuffer, &interval_value, 10) == FALSE)
    {
        _Printf("Parameter is not Decimal number\n");
        return;
    }
    
    InitializePIT(MS_TO_COUNT(value), interval_value != 0);
    _Printf("Time = %d ms. Interval = %s Change Complate\n",value, (interval_value == 0)? "False": "True"); 

}
void Command_PITWait(const char* _Parameter)
{
    char ParameterBuffer[200];
    PARAMETERLIST pList;
    InitializeParameter(&pList, _Parameter);
    if(GetNextParameter(&pList,ParameterBuffer)==0)
    {
        _Printf("wait {time(ms)}\n");
        return;
    }
    
    long value;
    if(_atoi(ParameterBuffer, &value, 10) == FALSE)
    {
        _Printf("Parameter is not Decimal number\n");
        return;
    }

    _Printf("%d ms Sleep Start...\n", value);

    DisableInterrupt();

    for(long i =0; i < value/30L; i++)
    {
        WaitUsingPITCounter0(MS_TO_COUNT(30));
    }

    WaitUsingPITCounter0(MS_TO_COUNT(value % 30));
    
    
    EnableInterrupt();
    _Printf("%d ms Sleep Complate.\n", value);
    InitializePIT(MS_TO_COUNT(1), TRUE); 
}
void Command_ReadTimeStamp(const char* _Parameter)
{
    QWORD tsc =  ReadTSC();
    _Printf("Time Stamp Counter = %q \n",tsc);
}
void Command_CPUSpeed(const char* _Parameter)
{
    QWORD last_tsc;
    QWORD total_tsc = 0;
    _Printf("Now Calculate.");
    DisableInterrupt();
    for(int i = 0; i < 200; i++)
    {
        last_tsc = ReadTSC();
        WaitUsingPITCounter0(MS_TO_COUNT(50));
        total_tsc+= ReadTSC() - last_tsc;
        _Printf(".");
    }
    InitializePIT(MS_TO_COUNT(1),TRUE);
    EnableInterrupt();
    _Printf("\n Cpu Clock = %d MHz \n", total_tsc/10/1000/1000);
}
void Command_ShowDateTime(const char* _Parameter)
{
    BYTE Second, Minute, Hour;
    BYTE DayOfWeek, DayOfMonth, Month;
    WORD Year;

    ReadRTCTime(&Hour, &Minute, &Second);
    ReadRTCDate(&Year,&Month,&DayOfMonth, &DayOfWeek);

    _Printf("Date: %d-%d-%d %s, ", Year, Month, DayOfMonth, ConvertDayOfWeekString(DayOfWeek));
    _Printf("Time: %d:%d:%d\n", Hour, Minute, Second);
    

}

```

It is just print command from the driver.

![Result!](/uploads/2017-08-03/OS/HelpCommand.png)

Commands are added like this, rdtsc command works properly.

![Result!](/uploads/2017-08-03/OS/TimeCommands.png)

The result of another command.

It prints date beautifully and measure CPU clock and waiting by milliseconds. 

Settimer works properly, but it cannot show by the image so I skip this.

I fixed two of bugs, first thing is not properly working unsigned value at _Printf function.

That fixed by %q and _u_itoa function.

Second is reset bug from wrong setup control port in control 0 in PIT. 

It fixed the changing control port.

Now we are going to make Task, multithread, synchronize and floating point.

I expect that.