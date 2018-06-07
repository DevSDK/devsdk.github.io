---
layout: post
title: GDT 변경 & IDT 정의 TSS 설정	
date:   2017-07-10 11:40:20		
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

중간중간, 다른거 할것도 생겼었고 이번건 디버깅이 좀 더 오래걸리기도 해서

지금 개발 일지를 올린다.

음....

일단, 지금까지 0SOS는 인터럽트를 처리할 수 있는 코드가 없었다.

그렇다 보니, 인터럽트가 발생하면 시스템이 다운되거나, default handler에 의해 처리되곤 했다.

아무튼간, 그건 맘에 안든다.

앞으로 키보드 입력할때건, 기타 여러 상황에서 인터럽트를 활용하기 위해 

이번에는 IDT라는 인터럽트 처리를 위한 준비물을 만들었다.

![결과임](/uploads/2017-07-10/OS/InterruptShow.png)

아직, 더미 핸들러로 연결이 되있긴 하지만 인터럽트가 발생을 했고, 그 인터럽트를 처리하기 위한 핸들러가 실행이 되었다.

저것을 위해 인터럽트 핸들링에 쓸 Stack Switching 용 IST 자료구조를

7~8MB 영역에 정의해주었다.

그리고 TSS Segment 를 이용해 IST를 지정해 주었고 IDT에 들어간 100여개의 더미 디스크립터는 Dummy Handler 함수와 연결했다.

메모리 맵을 만들면 대충 이럼.

![귀찮다](/uploads/2017-07-10/OS/MemoryMap.png)

다음엔 그냥 그림판으로 그려야겠다. 귀찮아져버려

아무튼 이번 코드의 핵심은 GDT에서 TSS Selector를 두는것과 TSS를 정의하는것 IDT를 만드는거라고 볼 수 있겠다.

아무튼, 말로만 하니까 저렇게 간단해 보이는데 음...

코드를 보자.

그리고 디버깅 일지를 쓰겠다.

일단 더미 핸들러.


```c
void DummyHandler()
{
    Pt(0,0,0x0F ,"===============================");
    Pt(0,1,0x0F ,"===============================");
    Pt(0,2,0x0F ,"===    Test Interrupt Hander===");
    Pt(0,3,0x0F ,"===============================");
    Pt(0,4,0x0F ,"===============================");
    
    while(1);   //복귀 코드 없음
}
```

어떤 인터럽트가 발생하면 일단 저쪽으로 연결된다.

즉, 숫자 나누기 0같은 연산을 시도했을때 인터럽트가 발생되어 저 함수가 실행이 된다.

결과는 첫 이미지처럼.

아무튼 이제 GDT를 재정의하고, TSS를 이용해 IST를 지정하고, IDT를 만들어 인터럽트를 처리할 수 있게 만들어야 한다.

그러기 위해 Descriptor 디렉토리를 만들고, 그 안에 그를 담당하는 파일들을 정의해 주었다.


![파일트리](/uploads/2017-07-10/OS/DirectoryTree.png)

Descriptor.asm과 Descriptor.h는, GDTR, IDTR , TSS 를 프로세서에 올리기 위한 어셈 코드들을 처리하며

IDT.c IDT.h 는 IDT와 관련된 코드

GDT.c GDT.h 는 GDT와 관련된 코드를 정의했다.

일단 GDT.h를 자세하게 보고 싶으시면

[이곳에서 보길 바란다. 너무 길다.](https://github.com/DevSDK/0SOS/blob/master/02_Kernel64/Source/Descriptor/GDT.h)

앞으로 자주 쓸 코드만 OR로 묶어서 define 해두었다. 
아무튼간, 
해더파일은 저렇고, 구현은 다음과 같다.
```c
//GDT.c

#include "GDT.h"
#include "IDT.h"
#include <Utility/Memory.h>

void InitializeGDTWithTSS()
{
    GDTR* _gdtr = (GDTR*)GDTR_POINTER;

    GDT_ENTRY8* _gdt_entry      = (GDT_ENTRY8*)(GDTR_POINTER + sizeof(GDTR)); 
    TSS_SEGMENT* _tss_segment    = (TSS_SEGMENT*)((QWORD)_gdt_entry+GDT_TABLE_SIZE);    
    _gdtr->Size         = GDT_TABLE_SIZE - 1;
    _gdtr->BaseAddress  = (QWORD)_gdt_entry;

    SetGDT_Entry8((&_gdt_entry[0]), 0, 0, 0, 0, 0);
    SetGDT_Entry8((&_gdt_entry[1]),0,0xFFFFF, GDT_ENTRY_HIGH_CODE, GDT_ENTRY_LOW_KERNEL_CODE, GDT_TYPE_CODE);
    SetGDT_Entry8((&_gdt_entry[2]),0,0xFFFFF, GDT_ENTRY_HIGH_DATA, GDT_ENTRY_LOW_KERNEL_DATA, GDT_TYPE_DATA);
    
    SetGDT_Entry16(((GDT_ENTRY16*)(&_gdt_entry[3])), (QWORD)_tss_segment, sizeof(TSS_SEGMENT)-1, GDT_ENTRY_HIGH_TSS,
                    GDT_ENTRY_LOW_TSS, GDT_TYPE_TSS);

    InitializeTSSSegment(_tss_segment);
    
}
void SetGDT_Entry8(GDT_ENTRY8* _entry, DWORD _BaseAddress,
                     DWORD _Size, BYTE _HighFlags, BYTE _LowFlags, BYTE _Type)
{
    _entry->Low_Size            =   _Size & 0xFFFF;
    _entry->Low_BaseAddress     = _BaseAddress & 0xFFFF;
    _entry->Low_BaseAddress1    = ( _BaseAddress >> 16 ) & 0xFF;
    _entry->Low_Flags           = _LowFlags | _Type;
    _entry->High_FlagsAndSize   = ((_Size>>16) & 0xFF) | _HighFlags;
    _entry->High_BaseAddress    = (_BaseAddress>>24) & 0xFF;
}

void SetGDT_Entry16(GDT_ENTRY16* _entry, QWORD _BaseAddress,
                     DWORD _Size, BYTE _HighFlags, BYTE _LowFlags, BYTE _Type)
{
    _entry->Low_Size            = _Size & 0xFFFF;
    _entry->Low_BaseAddress     = _BaseAddress & 0xFFFF;
    _entry->Mid_BaseAddress     = (_BaseAddress >> 16 ) & 0xFF;
    _entry->Low_Flags           = _LowFlags | _Type;
    _entry->High_FlagsAndSize   = ((_Size >> 16) & 0xFF) | _HighFlags;
    _entry->High_BaseAddress    = (_BaseAddress  >> 24) & 0xFF;
    _entry->High_BaseAddress2   = (_BaseAddress>>32);
    _entry->Reserved            = 0;
}

void InitializeTSSSegment(TSS_SEGMENT* _tss)
{
    _MemSet(_tss, 0, sizeof(TSS_SEGMENT));    
    _tss->IST[0] = IST_POINTER + IST_SIZE;
    _tss->IOMapBaseAddress  =  0xFFFF;
}

```

뭐, 자세히 보면 InitializeGDTWithTSS함수를 통하여, GDT관련 데이터를 메모리에 올려놓는다. (GDTR_POINTER를 유심히 보고, 계산하면 메모리가 딱딱 맞아 떨어진다.)

기존의 GDT구조랑 다른게 없으니 그건 구글링 해보시길 권장

그리고 IDT 쪽을 보자

IDT.h의 해더파일이다.

```c
//IDT.h

#ifndef __IDT_H__
#define __IDT_H__
#include "GDT.h"

#define IDT_TYPE_INTERRUPT      0x0E    //0b00001110
#define IDT_TYPE_TRAP           0x0F    //0b00001111
#define IDT_ENTRY_DPL0          0x00    //0b00000000
#define IDT_ENTRY_DPL1          0x20    //0b00100000
#define IDT_ENTRY_DPL2          0x40    //0b01000000
#define IDT_ENTRY_DPL3          0x60    //0b01100000
#define IDT_ENTRY_P             0x80    //0b10000000
#define IDT_ENTRY_IST1          1
#define IDT_ENTRY_IST0          0

#define IDT_ENTRY_KERNEL    (IDT_ENTRY_DPL0 | IDT_ENTRY_P)
#define IDT_ENTRY_USER      (IDT_ENTRY_DPL3 | IDT_ENTRY_P)

#define IDT_MAX_ENTRY_COUNT     100
#define IDTR_POINTER            (sizeof(GDTR) + GDTR_POINTER \
                                + GDT_TABLE_SIZE + TSS_SEGMENT_SIZE)
#define IDT_POINTER            (sizeof(IDTR) + IDTR_POINTER)
#define IDT_TABLE_SIZE          (IDT_MAX_ENTRY_COUNT + sizeof(IDT_ENTRY))


#define IST_POINTER         0x700000
#define IST_SIZE            0x100000


#pragma pack(push, 1)

typedef struct _Struct_IDT_Entry
{
    WORD Low_BaseAddress;
    WORD SegmentSelector;

    BYTE IST;
    //3Bit IST, 5Bit set 0
    BYTE FlagsAndType;
    // 4Bit Type, 1 Bit set 0, 2Bit DPL, 1Bit P
    WORD Mid_BaseAddress;
    DWORD High_BaseAddres;
    DWORD Reserved;

}IDT_ENTRY;

#pragma pack(pop)

void InitializeIDTTables();
void SetIDTEntry(IDT_ENTRY* _entry, void* _handler, WORD _Selector, 
                    BYTE _IST, BYTE _Flags, BYTE _Type);


void Pt(int _x, int _y, BYTE _Attribute ,const char* _str);

void DummyHandler();

#endif /* __IDT_H__ */

```

IDT.h 해더파일은 아직 길진 않다. 

자세히보면 알겠지만, 각각 시작주소를 나타내는 _POINTER의 경우 직접 지정하는것 보단, sizeof에 의해 메모리에 연속되게 배치되게끔 만들어졌다.


그리고 구현인 IDT.c

```c
//IDT.c
#include "IDT.h"

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
void SetIDTEntry(IDT_ENTRY* _entry, void* _handler, WORD _Selector, 
                    BYTE _IST, BYTE _Flags, BYTE _Type)
{
    _entry->Low_BaseAddress =  (QWORD) _handler & 0xFFFF;
    _entry->SegmentSelector = _Selector;
    _entry->IST             = _IST & 0x3;
    _entry->FlagsAndType   = _Flags | _Type;
    _entry->Mid_BaseAddress = ((QWORD)_handler >> 16) & 0xFFFF;
    _entry->High_BaseAddres = ((QWORD)_handler >> 32);
    _entry->Reserved        = 0;
}
//Pt, DummyHandler 생략

```
대충 dummyhandler하고, print vide memory를 담당했던 함수는 생략했다.

위 코드를 이용해 IDT를 정의하고 메모리에 불러오게 된다.

프로세서에 해당 핸들러를 이어주고 하는 역할을 하는게, Descriptor.h와 Descriptor.asm 이다. 

```c
//Descriptor.h

#ifndef __DESCRIPTOR_H__
#define __DESCRIPTOR_H__

void LoadGDTR(QWORD _GdtrAddress);
void LoadTR(WORD _TssSegmentOffset);
void LoadIDTR(QWORD _IDTRAddress);

#endif /*__DESCRIPTOR_H__*/

```

위 코드는 어셈블리랑 연결되어 있다. 해당 기능을 제공하는 어셈블리는

```nasm
;Descriptor.asm

[BITS 64]
                     
global LoadGDTR, LoadTR, LoadIDTR
                        
SECTION .text

LoadGDTR:
    lgdt[rdi]
    ret
LoadTR:
    ltr di
    ret

LoadIDTR:
    lidt[rdi]
    ret

```

간단하다. 그저, 각 테이블을 프로세서에게 알리는 코드이다.

그리고 마지막 대망의 커널 엔트리에는

```c
    //__Kernel_Entry.c
	PrintVideoMemory(5,12, 0x0F,"Initialize GDT........................................");
	InitializeGDTWithTSS();
	LoadGDTR(GDTR_POINTER);
	PrintVideoMemory(60,12,0x0A,"[SUCCESS]");
	PrintVideoMemory(5,13, 0x0F,"Load TSS Segment .....................................");
	LoadTR(GDT_TSS_SEGMENT);
	PrintVideoMemory(60,13,0x0A,"[SUCCESS]");
	PrintVideoMemory(5,14, 0x0F,"Initialize IDT .......................................");
	InitializeIDTTables();
	LoadIDTR(IDTR_POINTER);
	PrintVideoMemory(60,14,0x0A,"[SUCCESS]");
    //...

```
이 코드를 추가해 초기화 및 프로세서에 연결을 취해주고 키보드 입력할때

숫자를 0으로 나눠 divide by zero 인터럽트를 발생시켰다.

```c
//__Kernel_Entry.c
	if(flags & KEY_DOWN )
	{
		PrintVideoMemory(i++, 15, 0x0C, temps);
		int b = 10 / 0;
	}

```

여기까지가 코드상에 추가된 내용이다.

음... 앞으로 포스팅할때 코드를 다 붙여넣는건 고려를 좀 해봐야겠다.

더 나은 방법이 있을거같다. 위에 Kernel Entry 쓰는거 처럼.

이제 위 내용을 구현하며 했던 삽질과 디버깅 일지를 쓰겠다.


위 내용을 열씸히 코딩하고 나서, 기쁜 마음으로 Build를 시도했다.

```

undefined reference to ....


```


젠장.


뭐가 문제인지 찾아보기 시작했다.

링크 로그를 뚫어져라 보니, 어셈블리 목적파일이 이상한갑다.

그래서 objdump로 확인해보니 이럴수가 ... 파일 이름만 다르지 두 파일의 내옹이 똑같았다.

즉 asm code의 목적코드 변환이 이상하게 된것.

(대충 PortIO.o와 Descriptor.o 안에, Port.o 내용이 있었다.)

nasm은 gcc랑 대충 동작은 비슷한데 파일 여러개를 묶어서 빌드하는건 안되나보다.

```make
$(ASSEMBLYOBJECTFILES): $(ASSEMBLYSOURCEFILES)
 	$(NASM64) -o $@ $<
```

사실 $< 때문에 빌드가 된거지 $^ 박았으면 인자 많다고 nasm에서 멈췄을것이다.

저번까진 asm파일이 하나였으니 별 문제를 일으키진 않았는데, 

asm 파일이 두개 이상이 되니 빌드가 이상하게 됐다. 

gcc는 그냥 -c 옵션에 뒤에 소스파일을 죄다 주면 목적파일로 차근차근 빌드하나 싶었는데, nasm은 여러가지 파일을 인자로 안받는다 젠장.


그래서 방법을 고민했다.

처음엔 nasm 자체 기능으로 해결해볼까... 할수 있을까 고민했는데, 없었다. 아니 모르는건가...?


아무튼, 그냥 makefile에 foreach문을 넣는거로 해결했다.

```make

$(ASSEMBLYOBJECTFILES):$(ASSEMBLYSOURCEFILES)
$(foreach var,$(ASSEMBLYSOURCEFILES),$(NASM64) $(var) -o $(notdir $(patsubst %.asm, %.o,  $(var))) ;)
```

이 짧막한(아닌)코드를 위해 몇시간을 날려먹었다.

![빌드성공!](/uploads/2017-07-10/OS/BuildDone.png)

이제...makefile건들일은 많이 없겠지. 

아무튼 빌드는 잘 된다. 

실행해보았다. 

딱히 동작하지 않는다.

makefile때문에 멘탈이 흔들거렸던 나는 말그대로 부들부들 상태.

좀 쉬었다가, 다시 잡았다.

디버깅 할 내용은, GDT, IDT, TSS 데이터가 메모리에 잘 올라갔는지 확인하는것.


가장 처음으로 해볼껀, 명시적으로 메모리 주소를 지정했던 

GDTR을 살펴보는 것 이다.

![GDTHEX](/uploads/2017-07-10/OS/Hex_GDT.png)


초록색위는 GDTR, 빨간색은 GDT 테이블이다.

GDTR의 가장 중요한 역할은 GDT의 위치를 지정해 주는 것이다.

나는 GDTR바로 뒤에 GDT를 위치시켰으니 0x142010을 참조하고 있어야 할테고

HEX를 보면 재대로 저장이 되어 있음을 볼 수 있다.

그리고 뒤에나오는 GDT를 살펴보자.

아무튼, GDTR 지정하고 프로세서한테 넘기고 출력까지 잘 되기 때문에 GDT 테이블 내용 자체의 문제는 없을꺼라 생각했다.

다만, TSS 세그먼트디스크립터는 자세히 봤다.

시작점은 0x142028

표로 정리하면 다음과 같다.


![TSSSelector](/uploads/2017-07-10/OS/Table_TSS.png)


메모리에 잘 불러와 지는지 보고 있었으므로, 일단 Base Address를 살펴본다.

TSS 테이블 또한 GDT바로 뒤에 위치하게끔 의도했으므로

0x142038부터 위치해야한다.

일단 TSS 세그먼트디스크립터의 Base Address는 문제가 없어보인다.


![HEX_TSS_ERROR](/uploads/2017-07-10/OS/HEX_TSS_ERROR.png)


한두번 다시 봤다. 뭔가 이상해


마지막 2바이트 IOMap 설정에는 FFFF를 넣어놨는데 어디갔지?

IST의 기준주소인 0x800000 은 어디간거지.

코드로 돌아갔다.

아뿔싸

멀쩡한 InitializeTSSSegment 함수를 잘 만들얻두고 호출을 안했다.

InitializeGDTWithTSS 함수 마지막에 위 함수를 호출함으로 해결했다.


![HEX_TSS_WORK](/uploads/2017-07-10/OS/Hex_TSS_Work.png)

... 뭐가 달라진진 잘 안보이지만 마지막 2바이트가 FFFF로 들어갔고 잘 보면

IST 기준 주소도 저장이 되었다.

일단 여기까진 정상이다.

그래도 동작 안한다.

이제 그 뒤에 위치한 IDT를 살펴보았다.

흐음.

![HEX_IDT_ERROR?](/uploads/2017-07-10/OS/IDT_Error.png)

음...??

메모리 주소 계산이 이상하다.

의도한건 바로 뒤였는데 

왜 0x1421A0로 지정이 되어있는가..??

코드를 살펴보았다.

```c
IDT_ENTRY* entry =  (IDT_ENTRY*)IDTR_POINTER + sizeof(IDTR);
```
또 똑같은 실수를 -_-

저러면 당연히 뒤에 지정된다. 포인터로 케스팅하고 더해버리니까.

위 코드를

```c
IDT_ENTRY* entry =  (IDT_ENTRY*)(IDTR_POINTER + sizeof(IDTR));
```
로 변경하며 해결.

참고로 이 코드는 동작하는데 전혀 문제가 없다. 다만 의도랑 다를 뿐더러 추후에, 문제를 일으킬 수 있다. 예를들면, IDT 바로 뒤에 어떤 데이터를 넣는다고 했을때 주소게산이 되서 덮어써버릴 수 있다.

당장 안보이는 문제고, 주의깊게 보지 않으면 잡기 힘든 버그긴 하다.

(IDTR에 들어간 메모리 주소와 실제 IDT 위치가 같기 떄문이다. 실제로 0x2021A0에 가면 IDT가 있다.)

수정하니 정상적으로 데이터가 들어간다.



![HEX_IDT_WORK](/uploads/2017-07-10/OS/IDT_Work.png)


모든 데이터가 잘 들어갔다.

이상하게 동작을 안하네.

일단, 인터럽트가 걸리면 시스템이 다운되었다.

이상하다.

설마 해서 프로세서에게 전달을 잘못했나 살펴봤다.


```nasm

[BITS 64]
                     
global LoadGDTR, LoadTR, LoadIDTR
                        
SECTION .text

LoadGDTR:
    lgdt[rdi]
    ret
LoadTR:
    ltr di
    ret

LoadIDTR:
    lgdt[rdi]
    ret
```

아 ㅆ..

LoadIDTR 함수에서 
lgdt를 해버리는 실수를 저질렀다.

위 코드를 

```nasm
[BITS 64]
                     
global LoadGDTR, LoadTR, LoadIDTR
                        
SECTION .text

LoadGDTR:
    lgdt[rdi]
    ret
LoadTR:
    ltr di
    ret

LoadIDTR:
    lidt[rdi]
    ret
```

이 코드로 변경 함으로 해결

LoadIDTR 함수의 명령어를 lgdt 를 lidt로 변경했다.


이러서 코드가 정상적으로 돈다.



흠... 이번 글은 길다.

[이곳에서 Full Source Code를 볼 수 있다](https://github.com/DevSDK/0SOS)
간김에 스타도 박아주면 좋겠다.


이제 남은건, 키보드처리를 인터럽트로 만드는것 이려나.
