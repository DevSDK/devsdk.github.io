---
layout: post
title: OS개발-Frame Buffer에 때려박자.	
date:   2017-06-26 17:20:20		
categories: development
languages:
- english
- korean
tags:
- 0SOS
- OS
- Operating System
- System
- FrameBuffer
---		


다른모드는 아직 안만져 봐서 모르겠는데

그리고 GUI 쪽 FrameBuffer은 어떨지 모르지만 일단 아는 한에서 씀

리얼모드에서 텍스트 Video Memory 주소는 0xB800이다. 

여기서 한 글자는 2바이트를 먹는데, 1바이트는 아스키 케릭터 값, 2바이트는 속성값이다.

자세한건 [여기서](https://en.wikipedia.org/wiki/VGA-compatible_text_mode)

그러니까 부트로더를 짤때든 언제든 0xB800에 순서대로 'H',속성,'E',(속성)...

이렇게 집어넣으면 글자가 뜬다.

물론 깨끗하게 나올리가 없지.

기존에 ( QEMU ) BIOS가 만들어낸 데이터를 싹 비워줘야 한다.

그걸 위해서 Frame Buffer를 싹 비워줘야한다 ( 0으로 설정해야한다. )

비워주면서 속성도 넣어주고..

```nasm

[ORG 0x00]              ; Start Address 0x00
[BITS 16]               ; 16 bit codes


SECTION .text           ;text section.

jmp 0x07C0:START        ;코드 시작주로소 간다.


START:
	mov ax, 0x07C0      ; 부트로더의 시작 주소 ( 그 이전 주소엔 잡다한거 들어있음.)
	mov ds, ax          ; 데이터 세그멘트 지정
	mov ax, 0xB800      ; 비디오 메모리 주소 지정
	mov es, ax
	mov si, 0           ; 문자열 indexing에 쓰일 레지스터
	
.SCREENCLEARLOOP        ; 화면 비우는 레이블
	mov byte[ es: si],0 ; 0xB800부터 크기만큼 반복함

	mov byte[ es: si + 1], 0x0A

	add si,2
	cmp si, 80*25*2     ; si 가 80*25*2 (비디오 메모리 크기) 작을때 아래 코드 실행
	jl .SCREENCLEARLOOP ; 반복

	mov si, 0           ;초기화
	mov di, 0

.MESSAGELOOP:           ;화면에 메시지를 띄워주는 레이블
	mov cl, byte[MESSAGE1+si]   ;c언어로 치면 array[i] 임. 아래 Message1에서 하나하나씩
	cmp cl, 0                   ;0과 만나는지 봄
	je .MESSAGEEND              ;만나면 탈출

	mov byte[es:di],cl
	
	add si, 1                   ;문자를 나타내는 인덱스
	add di, 2                   ;비디오메모리에서 쓰이는 인덱스

	jmp .MESSAGELOOP

.MESSAGEEND
	jmp $

MESSAGE1:	db 'Hello World. Boot Loader Start', 0 


times 510 - ($-$$) db 0x00

db 0x55
db 0xAA



```


대충 주석좀 달아봤다

귀찮아


아무튼 

![HELLO](/uploads/2017-06-26/OS/HelloWorld.png)


잘 나온다.

딱히 뭔가 부트로더의 역할을 하는건 아니고 그냥

프레임버퍼에 글자 띄우는 바이너리가 되시겠다.

C언어로 HelloWorld 찍고서 이거랑 다른게 뭔가요 물어보면 때림.


