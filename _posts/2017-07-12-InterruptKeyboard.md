---
layout: post
title: 키보드 드라이버의 업데이트-인터럽트 방식	
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



이번글은 짧지 않을까 싶다.


오늘은 이상하리만큼 집중하기 힘들다.

이상하다..흐음

오전에 이상하게 집중이 잘되더니 이상하게 지금은 맥이 빠진다 

아무튼, 이번에는 만든거 종합해서 적용시키는 것만 했으니

그렇게 길지도 않을것 같다.


지금까지 쓰던 방식은 Port Map IO 로 PS/2의 메모리를 버퍼삼아 썼는데, 이제 인터럽트 방식으로 쓰면 저 버퍼를 쓸수 없다.

데이터를 넣는 시간과 빼는 시간이 너무 다르기 때문이다.

아무튼 이걸 해결하기 위해 보통 말하는 InputBuffer 를 만들었다.

자료구조는 Queue 

범용으로 사용할 것이라 디렉토리 이름 고민을 좀 했다.

DS는 뭔가 닌텐도 DS생각나서 싫고

DataStructure 는 뭔가 길다.

그래서 그냥

universal data structure 해서 UDS라고 했다.

UDS 안에 Queue.h Queue.c 파일을 만들어 줬다.


보통 말하는 원형 큐다.

진짜, 범용 큐기때문에 대충 자료구조 수업이나 지식을 가지고 있다면 별다른 어려움 없을것이다.

C로 구현해서 Queue Descriptor 을 첫번째 인자로 주면서 구별한다.


아무튼, 구체적인 구현이다.


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

많이 보는 그저 Queue일 뿐이다.

설명은 생략

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

코드가 보기 싫으면 그저, 큐라고 생각하고 넘어가도 될듯.


아무튼 이 자료구조를 이용해서 키보드 인풋 버퍼를 만들고 Interrupt Handling 함수에서 써먹게끔 해주면 된다.


일단, 범용큐를 keyboard.h 에 추가해준다.


그와더불어 키 데이터 관련 구조체를 추가해준다.


```c
//Keybuard.h
//....생략

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

//....생략
```

위 함수들의 구현은 다음과 같다.

```c
//Keyboard.c
//...생략
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
//...생략
```

위에서부터 버퍼로 쓸 큐를 초기화 하는 함수,

큐에 데이터를 집어넣을 용도인 ScanCode를 받아 키 데이터로 Push해주는 함수

큐에서 KeyData를 가져오는 함수입니다.


여기서 Queue에 집어넣는 코드에서 
```c
BOOL interrupt_status = SetInterruptFlag(FALSE);
```
로 인터럽트를 꺼버리는 걸 볼 수 있다.

그리고 큐에 삽입하고나서 다시 복구한다.

이는 흔히말하는 동기화 문제 와 비슷한 문제를 막기 위함이다.

큐 관련 연산도중엔 인터럽트를 막아, 인터럽트에 의한 연산 순서 변경 및 프로그램의 예끼치 못한 동작을 막는다.

SetInterruptFlag 함수는 Utility/Flags.h 에 정의되어있다.

구현 내용은
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

저번에 만든 ReadFlags, EnableInterrupt, DisableInterrupt를 이용해 구현한다. 


그 다음으로는, LED나 키보드 활성화 같은 요청을 보내고 결과를 대기하는 코드의 변경이다.

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
이 코드가 추가되었고

```c
    for(int i=0; i< 100; i++)
    {
        //....
    }
```
이렇게 ACK를 대기하는 코드부분에

```c
result = WaitACKWithScanCodePushQueue();

	if(result == FALSE)
		return FALSE;
```
대기함수를 추가해 변경했다.

[좀더 자세히 보려면 여기서](https://github.com/DevSDK/0SOS/blob/master/02_Kernel64/Source/Driver/Keyboard/PS2Keyboard.c)

그리고 Interrupt Handler 쪽 함수는 

```c
   if(PS2CheckOutputBufferNotEmpty() == TRUE)
    {
        BYTE scancode = PS2GetKeyboardScanCode();
        ConvertScanCodeWithPushKeyQueue(scancode);
    }
```
이 코드가 추가되면서 처리가 가능해졌다.

그리고 커널 엔트리의 입력 처리 부분을 큐를 사용하게 바꾼다.

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
이렇게 바꾸면서 큐를 이용해 입력을 처리 할 수 있게 되었다.

인터럽트 방식은 덤!

결과는 뭐...

보이는건 똑같다

![결과](/uploads/2017-07-12/OS/Result.png)

이제 Input Queue를 사용하기 때문에

나중에 추가적인 키보드 Input Driver를 추가적으로 구현하고 이 큐에 Push 하면 큐를 이용한 쪽은 문제가 없을것이다.

한마디로 하나의 층이 생긴거다..

나중에 USB Keyboard Driver를 작성할때 활용할 것으로 생각이 된다.

읽어주셔서 감사합니다.
