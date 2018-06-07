---
layout: post
title: 0SOS의 첫 BootLoader.
date:   2017-06-27 10:20:27		
categories: development
tags:
- 0SOS
- OS
- Operating System
- System
- Booting
- function
---		



뭔가를 습득한다는건 참 즐겁다.

물론 좀 고생해가면서 습득해야 기억에 남기때문에, 책의 example code를 

전부 따라치진 않는다.

이름 바꾸고 순서 바꾸고, 함수로도 바꿔보고.

기타등등 해보고 몇몇가지가 빠져서 고생도 해보고. 나름 그렇게 하면 재밌다.

물론 시간은 몇배 더 걸리지만.


이번에는 좀 부트로더라고 부를 수 있을거같다.

물론 플로피디스크를 대상으로 하는 것이지만, 나중에 하드디스크를 대상으로도 바꿀 수 있겠지.

아직은 배워가는 단계니까 이정도로 만족하기로 한다.

부트로더 실행해서 가상이미지 호출한 모습.


![BootLoader](/uploads/2017-06-27/OS/BootLoaderRun.png)


잘 실행 된다. 뒤에 1234567... 이렇게 숫자가 있는 이유는 부트로더가 재대로 돌아가는지

로드한 메모리로 점프했기 때문이다.


(로드한 메모리에는 섹터마다 숫자를 증가시키게끔 만들어 두었다(askii값때문에 10보다 커질 수 없음)

참고로 숫자 개수는 정확히 1024.

불러온 섹터의 숫자이다.

아무튼 부트로더의 실행 순서는 다음과 같다.

실행하자마자 일단 초기화를 진행한다. (스택, 주소등)

그러곤 메시지 출력 함수를 실행한다. 호출규약은 C언어로 치자면 cdecl 방식이다.

인자를 호출해준 쪽이 해제하니까. 뭐 이건 별로 중요하진 않음. stdcall로 바꿔도 문제 없다.

그러곤 바이오스 서비스를 이용하기 위해서 인터럽트를 건다.

오류 발생하면 오류 핸들러쪽으로 넘기고

아니면 완료.

그러곤 로드한 메모리로 점프함.

코드



```nasm
[ORG 0x00]
[BITS 16]

SECTION .text

jmp 0x07C0:START

;;;;;;;;;;;;;;;;;
;;;; CONFIG ;;;;;
;;;;;;;;;;;;;;;;;

TOTALSECTOR: dw 1024 ;



START:
	mov ax, 0x07C0
	mov ds, ax


	;;;;;;;;;; STACK INITALIZATION ;;;;;;;;;;
	mov ax, 0x0000
	mov ss, ax
	mov sp, 0xFFFE
	mov bp, 0XFFFE

	mov si, 0

	call CLEAR 


	;;;;;;;;;; PRINT HELLO ;;;;;;;
	push HELLO
	push 0
	push 0
	call PRINT
	add sp, 6
	;;;;;;;;;; PRINT LOAD INFO ;;;;;;
	push LOADINFO
	push 0
	push 1
	call PRINT
	add sp, 6


	
DISKRESET:
	mov ax, 0
	mov dl, 0
	int 0x13
	jc ERRORHANDLER

	;;;;;;;;;;; READ DISK SECTOR ;;;;;;;
	mov si, 0x1000
	mov es, si
	mov bx, 0x0000

	mov di, word[TOTALSECTOR]

.READ:
	cmp di, 0
	je BREAKREAD
	sub di, 0x1

	mov ah, 0x02
	mov al, 0x1
	mov ch, byte[TRACK]
	mov cl, byte[SECTOR]
	mov dh, byte[HEADER]
	mov dl, 0x00
	int 0x13
	jc ERRORHANDLER

	;;;;;;;;;; calculate Address
	add si, 0x0020

	mov es, si

	mov al, byte[SECTOR]
	add al, 0x01
	mov byte[SECTOR],al
	cmp al, 19
	jl .READ

	xor byte[HEADER], 0x01
	mov byte[SECTOR], 0x01

	cmp byte[HEADER], 0x00
	jne .READ
	add byte[TRACK], 0x01	
	jmp .READ
BREAKREAD:
	push LOADSUCCESS
	push 24
	push 1
	call PRINT
	add sp,6

	jmp 0x1000:0x0000

ERRORHANDLER:
	push DISKERROR
	push 24
	push 1
	call PRINT
	jmp $

PRINT:
	push bp,
	mov bp, sp
	
	push es
	push si
	push di
	push ax
	push cx
	push dx	

	mov ax, 0xB800
	mov es, ax


	mov ax, word[bp + 4]
	mov si, 160
	mul si
	mov di, ax

	mov ax, word[bp + 6]
	mov si, 2
	mul si
	add di, ax

	mov si, word[bp+8]
.PRINTLOOP
	mov cl, byte[si]

	cmp cl,0
	je .ENDPRINTLOOP

	mov byte[es:di], cl

	add si, 1
	add di, 2
	jmp .PRINTLOOP

.ENDPRINTLOOP
	pop dx
	pop cx
	pop ax
	pop di
	pop si
	pop es
	pop bp
	ret


CLEAR:
	push bp
	mov bp, sp
	
	push es
	push si
	push di
	push ax
	push cx
	push dx

	mov ax, 0xB800
	mov es, ax
	
.CLEARLOOP:
	mov byte[es:si],0
	mov byte[es:si+1], 0x0B
	add si,2
	
	cmp si,80*25*2
	jl .CLEARLOOP
	
	pop dx
	pop cx
	pop ax
	pop di
	pop si
	pop es
	pop bp
	ret	



HELLO: db 'Welcome To 0SOS.',0
DISKERROR: db 'ERROR', 0
LOADSUCCESS: db 'SUCCESS',0
LOADINFO: db 'Now Loading From DISK...', 0

SECTOR:	db 0x02
HEADER:	db 0x00
TRACK:	db 0x00






times 510 - ($ - $$) db 0x00

db 0x55
db 0xAA

```

로드 잘 됨.


잘 동작함.


이제 32비트 모드를 만질차랜가보다.


그전에 이전 작업들좀 처리하고.






