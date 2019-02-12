---
layout: post
title: Page 관련 자료구조 정의, 64비트로 시동 걸 준비.
date:   2017-06-30 09:21:20		
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
- Booting
- 64bit
---		

자꾸 64비트로 넘어가기만 하면 된다고 했는데

이번엔 정말이다.

64비트 모드에 키까지 꼽아놓고 돌리기만 하면 된다.

일단, 32비트 보호모드는 IA-32e 모드로 전환하기 위한 전단계기 때문에,

보호모드일때는 페이징을 활성화 하지 않았고, 관련 자료구조도 정의하지 않았다.

아무튼, 64비트 모드인, IA-32e 모드에서는 메모리 페이징 기능을 사용할 것이기

때문에 관련된 자료구조를 정의해줄 필요가 있다.


이중에서 메모리를 2MB씩 4단계를 거쳐 접근하는 4단계 페이징 방식과,

메모리를 4KB씩 5단계를 거쳐 접근하는 5단계 페이징 기법이 있다.

해당 구조는 다음과 같다.

그림에는 4-KB인 5단계로 써있지만, 나는 2MB를 쓰는 4단계 페이징 방식을 사용할 것이다.

PT 안씀.


![페이징](/uploads/2017-06-30/OS/PageTable.png)



난 여기서 4단계 페이징 방식을 사용할 것이다. 페이지 디렉터리 테이블 속의 엔트리하나는

2MB크기의 메모리를 페이징 하고, 그 테이블에는 512개의 엔트리가 들어올 수 있다.

즉 페이지 디렉터리 하나당 512 * 2MB = 1GB를 표현할 수 있으며, 우리는 64GB까지 지원할 것이기

때문에,  페이지 디렉터리 포인터는  64개가 필요하다. 따라서 그 전단계인 PML4 

테이블엔 엔트리 하나만 있으면 된다.

즉, 초기화해줘야 할 곳, 확보해줘야 할 메모리는 

PML4 테이블, 페이지 디렉터리 포인트 테이블, 페이지 디렉터리 테이블이다. 

각각 소스코드에선 PML4, PDPT, PD로 나타낸다.

또한, 각각의 엔트리마다 겹쳐지는 FLAG도 많기 때문에 메크로 BITFLAG를 제공한다.

이 자료구조로 필요한 총 크기는

PML4 엔트리는 8바이트씩, 512개가 필요하므로 512 * 8Byte

PDPT 엔트리도 8바이트씩, 512개가 필요하므로 512 * 8Byte

PD 엔트리는 8바이트 엔트리가 512개가 64개 있어야 함으로 (64GB 지원)

512 * 64 * 8Byte

각각 4KB, 4KB, 256KB

다 더해서 총 264KB 가 필요하다.

우리는 64비트 커널을 2메가바이트 영역을 엔트리로 지정할것이므로 

1~2MB영역에 이걸 적재하기로 한다.

```c

#ifndef __PAGE_H__
#define __PAGE_H__

#include "Types.h"

#define PAGE_FLAG_P			0x00000001
#define PAGE_FLAG_RW		0x00000002
#define PAGE_FLAG_US		0x00000004
#define PAGE_FLAG_PWT		0x00000008
#define PAGE_FLAG_PCD		0x00000010
#define PAGE_FLAG_A			0x00000020
#define PAGE_FLAG_D			0x00000040
#define PAGE_FLAG_PS		0x00000080
#define PAGE_FLAG_G			0x00000100
#define PAGE_FLAG_PAT		0x00001000	
#define PAGE_FLAG_EXB		0x80000000	

#define PAGE_FLAG_DEFAULT	(PAGE_FLAG_P | PAGE_FLAG_RW)
#define PAGE_TABLE_SIZE		0x1000 //4KB
#define PAGE_DEFAULT_SIZE	0X200000

#define PAGE_MAX_ENTRY_COUNT		512

#pragma(push, 1)



/*

	For IA-32e Paging
	IA-32e Address Structure
	63			48 47	39 38			   30 29	   21 20			0
	|SIGNEXTENSION| PML4 | DIRECTORY POINTER | DIRCTORY  |    OFFSET     |

	PML4 Refernce PML4 ENTRY
	and, that Refernce DIRECTORY POINTER ENTRY using DIRECTORY POINTER
	and, that Refernce DIRCTORY ENTRY using DIRECTORY 
	and, DIRECTORY + OFFSET is Memory Address. 
	
	so, We Need Space for this Structure
	
	PML4 Table Need 512 * 8 Byte = 4KB
	PAGE DIRECTORY POINTER Table Need 512 * 8 Byte = 4KB
	PAGE DIRECTORY Need 512 * 8 Byte * 64 = 256KB (for 64GB Memory)
	
	So we using 4KB + 4KB+ 256KB = 264KB Memory Space.

    The following code is its implementation.
    	
	We Use 4 Level Paging, So NOT USE PTENTRY.
*/

typedef struct __Struct_PageEntry
{	
	
	/*0----------------31 bit */
	DWORD dwLowAddress;
	/*32---------------64 bit */
	DWORD dwHighAddress;

} PML4ENTRY, PDPTENTRY, PDENTRY, PTENTRY;	

#pragma(pop)

void InitializePageTable();
void SetPageEntryData(PTENTRY* pEntry, DWORD dwHighBaseAddress, 
					  DWORD dwLowBaseAddress, DWORD dwLowFlag, DWORD dwHighFlag);



#endif /*__PAGE_H__ */

```

-_- 젠장, 애써 달아놓은 주석이 다 깨지네.


원래는 이렇게 보인다.

![이쁜주석](/uploads/2017-06-30/OS/64BitMemory.png)


이중 __Struct_PageEntry 는 64bit 크기의 테이블 엔트리를 표현하기 위함으로 정의되었다.

구조체중 PTENTRY는 사용되지 않는다. (5단계 페이징용.)


구현부는 다음과 같다.


```c


#include "Page.h"



void InitializePageTable()
{

	PML4ENTRY*	pml4entry  = (PML4ENTRY*) 0x100000;
	PDPTENTRY*	pdptentry  = (PDPTENTRY*) 0x101000;
	PDENTRY*	pdentry    = (PDENTRY*	) 0x102000;

	SetPageEntryData(&pml4entry[0], 0x00, 0x101000, PAGE_FLAG_DEFAULT, 0);

	for(int i = 1; i< PAGE_MAX_ENTRY_COUNT; i++)
	{
		SetPageEntryData(&pml4entry[i], 0,0,0,0);
	}

	for(int i = 0; i < 64; i++)
	{
		SetPageEntryData(&pdptentry[i], 0, 0x102000 + i * PAGE_TABLE_SIZE,
						 PAGE_FLAG_DEFAULT, 0);
	}

	for(int i=64; i < PAGE_MAX_ENTRY_COUNT; i++)
	{
		SetPageEntryData(&pdptentry[i], 0, 0, 0, 0);
	}

	DWORD LowMapping = 0; 
	
    /*
		'high' for Calculate out of 32bit area. using HighAddressArea 
	*/

	for(int i=0; i<PAGE_MAX_ENTRY_COUNT * 64; i++)
	{
		DWORD high = (i * (PAGE_DEFAULT_SIZE >> 20) ) >> 12;
		SetPageEntryData(&pdentry[i], high, LowMapping, 
						PAGE_FLAG_DEFAULT | PAGE_FLAG_PS, 0);				

		LowMapping += PAGE_DEFAULT_SIZE;
	}
	 

}


void SetPageEntryData(PTENTRY* pEntry, DWORD dwHighBaseAddress, DWORD dwLowBaseAddress,
					  DWORD dwLowFlag, DWORD dwHighFlag)
{
	pEntry->dwLowAddress  = dwLowBaseAddress  | dwLowFlag;
	pEntry->dwHighAddress = (dwHighBaseAddress & 0xFF )| dwHighFlag;
}

```

복잡해 보일 수 있는데, 그렇게 복잡하진 않다.

중간에 >>20 >> 12 이건, 32비트를 넘어서는 주소에대한 계산이다.

구조체를 이용해 64비트를 표현했으니까 말이다.

우리가 잘 정의한 FLAG들을 각 엔트리 주소에 넣어주는 것이며,

그 구조는 다음과 같다.

![그림판](/uploads/2017-06-30/OS/Memory.png)

그림판으로 대충 그린거니까 양해 바란다.

저렇게 해서 메모리에 다 넣어준뒤 Main.c에 초기화 구문을 넣어준다.

```c

	PrintVideoMemory(5,7, 0x0F,"Initalization PML4, PDPT, PD .........................");
	InitializePageTable();
	PrintVideoMemory(60,7,0x0A,"[SUCCESS]");

```

뭐, 이건 메모리 사이즈 체크를 끝내고 오류 발생할게... 없을것이다. 아마도...

그래서 그냥 SUCCESS.

출력해서 보면


![완성!](/uploads/2017-06-30/OS/PageInitOut.png)

저 한줄이 또 추가되서 기쁘다.

이제, 진짜로 64비트만 남았다.

이제 10장, 64비트로 전환하자.

또 링크스크립트 만지고, 잘 알지 못하는 makefile을 대거 수정할

생각하니까 걱정이 앞서긴 하지만 지금까지 만든거 보면 나름 뿌듯하다.

이제 부팅과정의 끝에 와간다.


[FULL 소스코드는 GITHUB에 올리고 있다.](https://github.com/DevSDK/0SOS)

내친김에 스타도 박아주셧으면 좋을것 같다..
