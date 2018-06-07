---
layout: post
title: 0SOS가 이제 C언어 코드 엔트리로 넘어갑니다. 이제 C언어다
date:   2017-06-29 00:51:20		
categories: development
tags:
- 0SOS
- OS
- ProtectedMode
- Operating System
- System
- 32bit
- Booting
- C Language
---		

이번 글은 좀 길꺼같다.


휴, 하루종일 OS만 만지니까 재밌네 하나하나가 다 새롭구만

오늘 오후쯤에 0SOS는 32비트로 넘어갔었다.

뭐 잡다한 과정을 거쳤다. GDTR을 구성하고 GDT구성하고

등등등.. 자세한건 [여기서 보시길](https://devsdk.github.io/development/2017/06/28/Hello32BIt.html)

이번에는 C언어 커널 소스코드로 넘어간다. 



![예스!](/uploads/2017-06-29/OS/Finaly.png)

저 한줄을 위해 몇시간을 삽질했는가.

위에서 돌린 C 코드는 다음과 같다.

```c

#include "Types.h"


void PrintVideoMemory(int x, int y, const char* _str);


void __Kernel__Entry()
{

	PrintVideoMemory(0,3, "Now C Language Binary.");
	
	while(1);
}

void PrintVideoMemory(int x, int y, const char* _str)
{
	CHARACTER_MEMORY* Address = ( CHARACTER_MEMORY* ) 0xB8000;
	
	int i = 0;
	
	+= ( y * 80 ) + x;

	for ( i = 0; _str[i] != 0; i++)
	{
		Address[i].bCharactor = _str[i];
	}


}

```

이 코드가 위에 보는거처럼 잘 동작한다!

이번에도 뭐가 필요한 준비과정도 많았고 삽질도 많았는데,

일단 필요한건, 링커가 동작하는걸 제어하고, 코드에 대한 빌드 스크립트 수정, 엔트리포인트에서 C언어 엔트리포인트로 점프



기본적으로 32비트 코드를 쓸 수 있기때문에 컴파일러가 뱉어내는 데이터를 쓸 수 있다.

물론 제공되는 설정으로는 쓸 수 없다. 기본적으로 제공되는 설정에서는 코드의 위치나, 재배치를 위한 코드

운영체제를 위한 코드 등등등 커널코드에 불필요한 내용들이 많기 때문이다.

라이브러리를 붙이고, 링크까지 해버리는 경우도 있다.

게다가 내가 정의한 섹션정보마져 다르다.

그래서 필요한건 링크스크립트를 수정해야 하는것.

물론 나는 링크스크립트에 대한 지식이 없었다.

저자분도 그 부분을 설명하려면 책한권분량이 나온다고 해서 일단 따라쳤다.

대충 이해가 간다. 물론 큰 구조만.

작성한 링크스크립트 전부를 올리진 않겠다. 그게 중요한게 아니다.

보고싶으시면 [여기로 가서 보시길](https://github.com/DevSDK/0SOS/blob/master/LinkerScript.x)

일단 내용을 전부 이야기하기는 힘들다. 기반이 되는 코드는 /usr/lib/ldscript/elf_i386.x

에서 가져와서 불필요한 부분으로 생각되는걸 제거하고

필요한것인 섹션순서를 바꾸고, 주소를 지정해 주었다.

일단 가장 중요한 부분이


```Logos
	/*생략*/
  
  .text 0x10200      :
  {
    *(.text.unlikely .text.*_unlikely .text.unlikely.*)
    *(.text.exit .text.exit.*)
    *(.text.startup .text.startup.*)
    *(.text.hot .text.hot.*)
    *(.text .stub .text.* .gnu.linkonce.t.*)
    /* .gnu.warning sections are handled specially by elf32.em.  */
    *(.gnu.warning)
  }

	/* 생략 */


  .data           :
  {
    *(.data .data.* .gnu.linkonce.d.*)
    SORT(CONSTRUCTORS)
  }
  	/* 생략 */

}

```


일단 아마, 기존의 코드를 절반이상 수정한 것 같다.


대충 보면 .text 섹션의 시작점을 0x10200으로 지정하고

데이터 섹션을 뒤에 오도록 한다.

대충 이렇게 수정하고

커널로 쓸 c언어 파일을 gcc로 옵션을 잔뜩 붙여서 컴파일한다.

```
gcc -c -m32 -ffreestanding Main.c
```

이렇게 컴파일하면 링킹이안되고, 32비트 코드 그리고 다른 라이브러리를 불러오지 않는다.

그렇게 생긴 목적파일을 

다시 링킹해준다.

이상태로는 실행 못하고 그냥 목적파일일 뿐이다.

디스어셈블링 하면 다음과 같다.


참고로 이미지에 있는 어셈블리 코드는 위의 커널코드가 아니라 이거 글 작성용로 

수 3개 더하는 함수로 예를 든거다.

![이렇게 보임](/uploads/2017-06-29/OS/NotLink.png)

보면 명령주소가 0부터 시작이다. 

그래서 아까 열씸히 작성해준 링커스크립트를 이용해 링크하는데

```
 ld -elf_i386 -nostdlib -T LinkerScript.x Main.o Main.elf
```

뒤에 뭐가 더 붙긴하는데 생략.

저렇게 하면 명령어도 재배치가 되고

쓸수 있게끔 만들어준다.

![이렇게 보임](/uploads/2017-06-29/OS/Linked.png)

명령어가 중요한게 아니다 그냥 시작 주소가 다르다.


아무튼, 이렇게 지정해뒀다면 마지막으로 작성한 커널 엔트리 포인트에서

32비트 코드를 초기화하고

C언어로 뽑아낸 시작점으로 점프하는 일이다.


``` nasm

 
 [BITS 32]
 
 PROTECTEDMODE:
     mov ax, 0x10
     mov ds, ax
     mov es, ax
     mov fs, ax
     mov gs, ax
 
     mov ss, ax
     mov esp, 0XFFFE
     mov ebp, 0XFFFE
 
     push (SWITCHMESSAGE - $$ + 0x10000)
     push 2
     push 0
     call PRINT
     add  esp, 12
 
     jmp dword 0x08:0x10200      ;Let's Jump To C

```


이렇게 하고 빌드 스크립트 작성하는거도 좀 빡셧다.

아무래도 makefile 부분을 한번 살펴봐야 할거같다.

아무튼, 한두시간 삽질해가면서 빌드스크립트 쓰고

오류 수정해서 빌드 완료.

두근두근, 실행하는 순간

![터짐](/uploads/2017-06-29/OS/VMExplod.png)

첫 사진처럼 나왔어야 하는데..

VM이 터져버렸다.

왜 터진지는 짐작이 갔다.

저번에 수정한 부트로더 읽을 섹션을 하나밖에 지정해주지  않았기 때문이겠지..

수정하니까 윗 사진처럼 재대로 동작한다.

이제 저렇게 터졌을때 나온 덤프파일 읽어서 왜 그렇게 되는가를 도출해보는 연습을 해야겠다.



후우, 점점 복잡해지기 시작하는구만

끝까지 한번 해보자.