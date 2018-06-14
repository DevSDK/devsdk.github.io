---
layout: post
title: 	시간과 관련된 드라이버 개발 완료.
date:   2017-08-03 11:11:20		
categories: development
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


후 드디어 OS개발에 손댈 수 있는 시간이 났다.

그동안 이곳 저곳 다니고 일정이 계속 겹쳐서 시간이 나질 않았다.

사실 노트북 들고다니면서 중간 중간 만지긴 했는데 큰 변화는 아니라서 글 쓰진 않았다.

본문이 시작되기 전에 변경된건

Types.h 에 정의되어있는 BOOL 타입을 unsigned char 을 c99 이후 정의된 _Bool 타입으로 변경했다.

그 이유는 말하자면 조금 복잡한데.

여러이유가 있겠지만 unsigned char 에 대한 ! 연산을 이유로 들겠다.

보통 Not 연산을 진행할때 n xor 1 로 처리하개 되면 빠르게 연산 할 수 있다.

그런데 얼마전에 unsigned char (이전의 BOOL) 에 대한! 연산자랑 n xor 1 의 차이를 보았다.

![UC_NotOp](/uploads/2017-08-03/OS/UC_NOT.png)


![UC_XorOp](/uploads/2017-08-03/OS/UC_XOR.png)

두 코드를 살펴보면 확실하게 차이가 난다.


물론 컴파일러 최적화 옵션인 -O3 같은 옵션을 붙이면 아마 xor로 변하겠지만, 아무래도 최적화 옵션을 적용했을때 의도하지 않은 동작을 할 가능성이 높다.

일단 최적화 옵션을 붙이지 않는 가정 하에 not 연산은 딱봐도 연산이 많다.

cmp 후 setne를 통해 데이터를 설정하게 되는데, 이는 시스템에서 t/f 를 구분할때 쓰는 비트 외에도 사용 될 수 있음을 가정한 것이라고 정리할 수 있다.

이건 _Bool 타입으로 변경하면서 해결(컴파일 하면 두 코드가 동일하게 컴파일 된다. 기억상으론 xor을 썻던 것 같다.)

---

이제 드디어 본문이다.

이번에는 전반적으로 타이머, 시간과 관련된 부분을 개발했다.

좀더 구체적으로

PIT(Programmable Interval Timer) Driver 의 개발과 Timestamp 그리고 RTC(Real Time Clock) Driver 의 개발이다.

이번에 개발한 드라이버 묶음의 소스 트리이다.


![SourceTree](/uploads/2017-08-03/OS/TimeTree.png)


일단 PIT에 접근하는 건

PortIO Driver를 통해 0x43, 0x40, 0x41, 0x42 로 접근 가능하다.

뭐 PortMapIO 가 그렇듯 여러 비트를 열씸히 설정해 주어야 한다. 그중 가장 많으 쓰일것 같은 0x43 컨트롤 필드는 

7,6 - SC : Select Counter 커멘드의 대상이 되는 카운터

5,4 - RW : Read/Write 읽기 쓰기 여부 

        00: 카운터의 현제 값을 읽음 (2byte)

        01: 카운터의 하위 바이트를 R/W (1Byte)

        10: 카운터의 상위 바이트를 R/W (1Byte)

        11: 카운터의 하위 바이트에서 상위 바이트 순으로 R/W (2Byte)

3,2,1-Mode: PIT 컨트롤러의 카운트 모드 설정

        000: 모드 0 (Interrupt during counting)

        001: 모드 1 (Programmable monoflop)

        010: 모드 2 (Clock rate generator)

        011: 모드 3 (Square wave generator)

        100: 모드 4 (Software-triggered impulse)

        101: 모드 5 (Hardware-triggered impulse)

0   - BCD : 카운터의 값을 바이너리 도는 BCD 포멧으로 설정한다.

        BCD 포멧은 0~9999 까지

        바이너리 타입은 0x00~0xFFFF 까지

각 필드에 대한 자세한 설명은 생략하겠다.

아무튼 SC 필드에 의해 카운터가 선택이 되고 아래는 그 옵션이라고 보면 된다.

아래는 PIT관련된 상수 정의와 함수의 정의가 담겨있는 Driver/Time/PIT.h 이다.
```c
#ifndef __PIT_H__
#define __PIT_H__

#include <Types.h>
//PIT의 동작 속도 1.193182MHz 
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

PIT 장치의 동작 클록은 1.19318 Mhz로 동작하며 매회 카운터의 값을 1씩 감소시켜 0이 될때 신호를 발생시킨다.

클록을 기준으로 동작하는 PIC를 우리가 통상 사용하는 '시간'으로 사용하기 위해서 t = 1193182 * rate ( ex: 1ms rate = 0.001 ) 식을 쓴다.

0SOS는 카운터 0를 사용할 것이며 이전부터 카운터 1과 2는 메인 메모리와 PC 스피커를 위해 쓰인다고 한다.

뭐 위 함수 구현하는건 어쩌피 열씸히 PortMapIO를 통해 데이터를 읽고 쓰고 하는 것 뿐이라 복잡하지 않다.


```c
#include "PIT.h"
#include <Driver/IO/PortIO.h>

void InitializePIT(WORD _Count, BOOL _IsInterval)
{
    //만약 주기적으로 실행되어야 한다면 모드 2 아니면 모드 0
    if(_IsInterval == TRUE)
        PortIO_OutByte(PIT_PORT_CONTROL, PIT_COUNTER0_FLAG_INTERVAL);
    else
        PortIO_OutByte(PIT_PORT_CONTROL, PIT_COUNTER0_FLAG_ONCE);
    //카운터의 하위 비트와 상위 비트를 설정
    PortIO_OutByte(PIT_PORT_COUNTER0, _Count);
    PortIO_OutByte(PIT_PORT_COUNTER0, _Count >> 8);
}

WORD ReadTimerCount0()
{
    BYTE high, low;
    WORD ret = 0x0000;
    //Counter 0 의 데이터를 읽어온다.
    PortIO_OutByte(PIT_PORT_CONTROL, PIT_COUNTER0_FLAG_LATCH);
    low = PortIO_InByte(PIT_PORT_COUNTER0);
    high = PortIO_InByte(PIT_PORT_COUNTER0);
    //상위 비트 하위 비트 묶어서 2바이트로 변환
    ret = high;
    ret = (ret << 8) | low;
    return ret;
}

void WaitUsingPITCounter0(WORD _Count)
{
    //0~0xFFFF 까지 반복

    WORD CurrentCounter = 0;
    InitializePIT(0, TRUE);
    const WORD LastCounter0 = ReadTimerCount0();
    while(TRUE)
    {
        //Get Counter 0 Value
        CurrentCounter = ReadTimerCount0();
        //시간이 흐름에 따라 값이 커짐  
        if(((LastCounter0 - CurrentCounter) & 0xFFFF) >= _Count)
            break;    
    }

}
```

보면 크게 복잡한 건 없다.

PIT 타이머를 초기화 하는 함수와 Counter 0 의 값을 읽어오는 함수, 그리고 그럴 이용해 ms 단위 대기 함수가 끝.

그럼 다음은 타임 스탬프다. 

타임 스탬프는 클록 과 버스 속도 비율에 따라 올라간다고 한다. 따라서 정확하게 올라가는데, 이를 통해 정확한 속도 측정이 가능하다.

코드는 정말로 간단한데,
```nasm
;Driver/Time/TSC.asm
[BITS 64]

SECTION .text

global ReadTSC

;타임 스탬프 카운터를 읽어서 반환
ReadTSC:
    push rdx
    rdtsc   ;타임 스탬프 카운터의 값을 rdx:rax에 저장
    shl rdx, 32 ; rdx 레지스터의 상위 32비트 tsc 값과 rax레지스터의
    or rax, rdx ; 하위 32비트 tsc값을 rax에 저장
    pop rdx
    ret
```

RDTSC 명령어를 이용해 불러오게 된다.


그 다음으론 RTC 드라이버인데, 

RTC 컨트롤러는 시간 저장을 담당하는 컨트롤러다. 또한 PC가 꺼진 이후에도 기록하기 위해 전원을 쓴다. 

맞다 그 메인보드의 수은전지 와 같은것 말이다.

CMOS 메모리 안에 RTC 데이터가 가 기록되어 있다. CMOS 에 접근해서 RTC 데이터를 가져와야 한다.

CMOS 메모리는 는 ProtIO Driver로 접근 가능하며 메모리 어드레스 포트 0x70 과 메모리 데이터 포트 0x71로 접근이 가능하다.

RTC 관련된 주소 필드 표다.

![CMOSMemory](/uploads/2017-08-03/OS/CMOSField.png)

위 표를 참고해서 만들면 된다.



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

//BCD 코드 변환 - BCD 코드: 1바이트를 4비트씩 잘라서 10진수 2자리로 표현 ex) 0010 0001 이면 21
#define  BCD_TO_BIN(x) ((((x) >> 4) * 10) + ((x)  & 0x0F ))
void ReadRTCTime(BYTE* _Out_Hour, BYTE* _Out_Minute, BYTE* _Out_Second);
void ReadRTCDate(WORD* _Out_Year, BYTE* _Out_Month, BYTE* _Out_DayOfMonth, BYTE* _Out_DayOfWeek);
char* ConvertDayOfWeekString(BYTE _DayOfWeek);

#endif /*__RTC_H__*/
```

주소 필드를 정의하는 것과 데이터를 가져오는것, 요일을 문자열로 변경하는역할을 한다.

그리고 CMOS에서 가져온 RTC 데이터는 BCD 코드여서 바이너리로 변경하는 코드가 필요하다.

뭐 이것도 portIO로 열씸히 가져오는거라 딱히 뭐 말할건 없다.


```c
//Driver/Time/RTC.c
#include "RTC.h"

void ReadRTCTime(BYTE* _Out_Hour, BYTE* _Out_Minute, BYTE* _Out_Second)
{
    BYTE data;
    //CMOS 메모리에서 시간에 관련된 정보를 읽어오는 함수 값은 BCD 코드
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
    //CMOS 메모리에서 날자와 관련된 정보를 읽어오는 함수 값은 BCD 코드
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
    //날자를 요일 문자열로 바꿔주는 함수
    static char* WeekStringTable [8] = {"NULL", "Sunday", "Monday", "Tushday", "Wednesday", "Thursday", "Friday", "Saturday"};

    if(_DayOfWeek >= 8)
        return WeekStringTable[0];

    return WeekStringTable[_DayOfWeek];
```

이로서 드라이버가 완성이 되었다!!


이제 이 드라이버를 열씸히 활용하는 셸 커멘드를 만들었다.


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

복잡시럽게 보이지만 자세히 보면 양만 많지 단순히 값을 받아와서 출력하는것에 불과하다.


![결과!](/uploads/2017-08-03/OS/HelpCommand.png)

커멘드는 이렇게 추가 되었으며 rdtsc 명령어가 멀쩡히 동작한다.

![결과!](/uploads/2017-08-03/OS/TimeCommands.png)

다른 명령어에 대한 결과이다.

date를 멋지게 받아오기도 하고

cpu clock 측정도 하고

특정 ms 동안 대기하기도 한다.

settimer 명령어도 멀쩡히 동작하나, 이미지로 보여주기엔 한계가 있어서 뺏다.

개발하면서 두가지의 버그를 수정했는데, 하나는 _Printf 함수에 대한 unsigned 값의 의도하지 않은 동작이다.

이는 %q 출력 문자와 _u_itoa 함수를 호출하면서 해결을 하였다.

또 하나는 PIT 에서 컨트롤러0 의 값을 가져올때 실수로 control port를 넣어야 할걸 counter port 를 넣게 되어 계속 리셋이 되는 버그가 있었다.

이는 control 포트로 고치면서 해결했다.

아무튼 여기까지 왔다.

이제 테스크, 멀티쓰래드, 동기화, 실수 연산으로 나아간다.

기대중임.