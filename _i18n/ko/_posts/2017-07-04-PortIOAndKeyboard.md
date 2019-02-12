---
layout: post
title: PortIO 메모리와 PS/2 Keyboard IO 입력처리
date:   2017-07-04 22:00:20		
categories: development
languages:
- english
- korean
tags:
- 0SOS
- OS
- Operating System
- System
- Paging
- Input
- Keyboard
- 64bit
---		


어제부터 오늘까지 고민하면서 만든 결과물이다.

![키보드입력](/uploads/2017-07-04/OS/Keyboard.png)

저기  저 빨간글씨가 방금 입력한 텍스트.

이제 0SOS는, 키보드 입력을 지원한다.

물론 아직 쉘 이런건 아니고, 키보드 드라이버가 완성이 되었다.

입력받은걸 Video Memory에 넣는 정도.

조금 걱정인건 이게, PS/2 인터페이스 (옛날 컴퓨터에 있는 동그란 그거)

버전이다. 물론, 책에 이렇게 써있다고 그대로 개발할 내가 아니다.

그렇지만...

자료를 찾아보고 고민해보고, 심지어, 저자분께 직접 물어본 결과


![저자1](/uploads/2017-07-04/OS/writer1.png)


![저자2](/uploads/2017-07-04/OS/writer2.png)


라고 하신다. 

PCI를 직접 제어해야 한다고 하셔서 일단 보류하고, 추후에 추가가 가능하게끔

작성하도록 해야겠다.

대충 책을 훑어보니까 Input데이터를 Queue에 넣어서 Buffer처럼

활용하는 형태기 때문에, Queue를 인터페이스로써 활용이 가능해보인다.

일단 나중에 USB Driver, PCI Control 이 가능해질때쯤 다시 작성하기로 하고

일단, PS/2 버전의 키보드로 작성하기로 한다.

다행스럽게도 노트북 키보드는 PS/2로 내부적으로 연결되어있다고 한다.

개발에 큰 지장은 없어보인다.


슬슬 본격적으로 개발에 들어가기 때문에, 소스코드를 구분해 줄 필요가 있어보인다.


그래서 Source 폴더 안에, Driver 라는 디렉토리를 만들고

생각하기로 한다.

내가 사용할 방법은 [포트 맵 IO](https://ko.wikipedia.org/wiki/%EC%9E%85%EC%B6%9C%EB%A0%A5_%EB%A7%B5_%EC%9E%85%EC%B6%9C%EB%A0%A5) 이기 때문에, PortIO 관련된 디렉토리

키보드와 관련된 디렉토리를 구분했다.

그렇게 대충 디렉토리를 구분해서 tree 만들었다.

![DirectoryTree](/uploads/2017-07-04/OS/DirectoryTree.png)


*gch파일은 뭐 왜 추가되는진 모르겠다, 젠장 gcc 돌릴때 해더파일하고 같이 들어가면 저렇게 된다던데 통 해결법을 모르겠다. - 나중에 시간들여서 make를 한번 더 뜯어야 할듯


일단, 디렉토리가 생기면서 발생하는 include의 ../../ 가 싫어서

gcc에 옵션으로 Source디렉토리를 Include Path로 지정해주었다.

```
gcc -I ../Source
```

그러면 이제,

```c
#include "../../Types.h" //을 아래처럼 쓸 수 있다.
#include <Types.h>
```

아무튼 좀 더 나아지게끔 하려고 노력좀 했다.


이제  대망의 빌드.

빌드가 안됨

```
undefined reference to PS2~~
```

이런 메시지가 뜬다

좀더 자세히 보면 해더만 컴파일하고, 소스파일은 컴파일을 하지 않고 냅둔다.

아마도 책에서는 단일경로를 기준으로 작성이 되어서 그런듯 해보인다.

이제 makefile을 뜯어고치기 시작.

삽질 엄청 하면서 한 3시간정도 고생한거 같은데,

이것저것 해보다가 결과적으로 바꾼곳은 다음이다.


02_Kernel64/makefile 이다.
```make

CSOURCEFILES = $(wildcard ../$(SOURCEDIR)/*.c)
ASSEMBLYSOURCEFILES = $(wildcard ../$(SOURCEDIR)/*.asm)
```
C코드와, 어셈블리 코드를 지정해 주는 식을 
```make
CSOURCEFILES = $(shell find ../$(SOURCEDIR)/ -name *.c)
ASSEMBLYSOURCEFILES = $(shell find ../$(SOURCEDIR)/ -name *.asm)
```
로 변경해 주었다, 이러니까 모든 c 파일을 대상으로 가져오기는 하는데, 컴파일을 제대로 하지 않았다.

그래서 저상태로 돌리면 ld 명령어로 링크하는 과정에 파일이 없어서 링크를 못하는 상황.

그래서 o 파일을 만드는 규칙을 수정했다.

```make
%.o: ../$(SOURCEDIR)/%.c		 
 		$(GCC64) -c $<		 
%.o: ../$(SOURCEDIR)%.asm
		$(NASM64) -c $@ $<
```
위 코드를, 

```make
$(COBJECTFILES): $(CSOURCEFILES)
	$(GCC64) -c $^
$(ASSEMBLYOBJECTFILES): $(ASSEMBLYSOURCEFILES)
	$(NASM64) -o $@ $<
```
로 수정하면서, 모든 파일들을 빌드한뒤 Obj 디렉터리 안에 넣게 된다.

그래서 링커가 실행되고

정상적으로 디스크가 구워진다.



![BuildComplate](/uploads/2017-07-04/OS/BuildComplate.png)

이 장면을 보고 소리지를 뻔 -_-

아무튼간, 

빌드에는 성공했고, 기쁜 마음으로 실행

깜빡깜빡 -_-;;; 왜그런가 이유를 찾아다녔다.

gdb를 써보고 싶었는데 통... 못쓰겠다. 게다가 qemu에서 호스트해주는거라

스탭스탭 밟는거도 안되는 듯 해보인다.

나중에 GUI 버전을 찾아봐야겠다.

무튼, 그 이유를 찾았는데, 

PortIO 어셈블리 함수 두개와 그걸 잇는 해더파일의 함수와

반대로 이어져 있었다.

그래서 반환도 재대로 안되고, 인자도 재대로 안들어가서 스택 터지고 

다운이 된듯 하다.

그렇게 PortIO 기능을 쓸 수 있게 되고

PS/2 Keyboard 포트를 이용해 키보드 드라이버를 작성하기 시작했다.



[키보드 드라이버 소스코든는 좀 긴거 같으니까, 전체 코드는 여기서](https://github.com/DevSDK/0SOS/tree/master/02_Kernel64/Source/Driver/Keyboard)

사용자가 키보드를 누르면 스캔 코드가 전달되는데, 

쉬프트와 캡스락과 같은 기능을 쓰기 위해서 키보드의 상태를 담당할 g_KeyboardStatus를 두고, 해당 키를 누를시 업데이트 하는 형태로 구현했다.

```c
//Keyboard.h
typedef struct _KeyboardSataus
{
	BOOL isShiftKeyDown;
	BOOL isCapsLockOn;
	BOOL isNumLockOn;
	BOOL isScrollLockOn;

	BOOL isExtendCode;
	int  SkipPauseCount;

} KeyboardStatus;



static KeyboardStatus	g_KeyboardStatus= { 0,};


```

그리고 스캔코드-아스키코드 맵을 만들었다.

조합키가 입력될경우와, 일반적인 경우를 구분했다.

```c
//Keyboard.h
typedef struct _StructKeyMapEntry
{
	BYTE 	NormalCode;
	BYTE 	CombinedCode;

} KeyMapEntry;


static KeyMapEntry 		g_KeyMapScanTable[KEYMAP_TABLE_SIZE] = {
	{ KEY_NONE				,		KEY_NONE		}, //    0
	{ KEY_ESC 				,		KEY_ESC			}, //    1
	{ '1'					, 		'!'				}, //    2
	{ '2'					,		'@'				}, //    3
	{ '3'					,		'#'				}, //    4
	{ '4'					,		'$'				}, //    5
	{ '5'					,		'%'				}, //    6
	{ '6'					,		'^'				}, //    7
	{ '7'					,		'&'				}, //    8
	{ '8'					,		'*'				}, //    9
	{ '9'					,		'('				}, //    10
	{ '0'					,		')'				}, //    11
	{ '-'					,		'_'				}, //    12
    // 나머지는 생략 89개다.

```

아무튼 저 테이블을 참조하여, 키보드 입력 처리를 하게 된다.

내부 구현은 깃헙에서.

그래서 커널 엔트리에서 사용할땐

```c
//__Kernel_Entry.c
void __KERNEL_ENTRY()
{

	PrintVideoMemory(5,12, 0x0F,"64 bit C Language Kernel.");	
	BYTE flags;
	int i = 14;
	char temps[2] = {0,};

	if(PS2ActivationKeyboard() == FALSE)
	{
		PrintVideoMemory(5,15, 0x0F,"Keyboard Error	.");	
		while(1);
	}
	
	
	while(1)
	{
		if(PS2CheckOutputBufferNotEmpty() == TRUE)
		{

			BYTE temp = PS2GetKeyboardScanCode();
			if(ConvertScancodeToASCII( temp, &temps[0], &flags) == TRUE)
				if(flags & KEY_DOWN )
					PrintVideoMemory(i++, 15, 0x0C, temps);
			
		
		}


		
	}
	
}

```
로 사용한다

보면 입력값이 있으면 그 값을 가져오고 ASKII로 변경한뒤, 키 입력인지를 판별해 출력해주는 형태.

아직 인터럽트를 사용하지 않는다.

아무튼 잘 나오니까 너무 기쁘다. 드디어 곧 쉘이라는걸 내 손에....


아무튼 다음은 인터럽트네.. 조금 험난할껏 같다.

[Kernel64의 Full Source Code](https://github.com/DevSDK/0SOS/tree/master/02_Kernel64)

자세한걸 보고싶으신 분은 여기서 Driver 쪽과, 커널 엔트리를 보시면 될것 같다.

내친김에.. 스타도....눌러주시면...


