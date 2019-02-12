---
layout: post
title: 리얼모드에서 메모리 접근하는 방식	
date:   2017-06-26 20:02:20		
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
- Memory
---		


2시간 날렸는데, 내가 잊어먹고 있던거였다.

분명 읽었었는데 왜 잊어버린걸까.


es레지스터에 들어간 0x020을 512로 표현하고 있길레 2시간동안 엄한대서 해매고 있었네

물론 저 숫자만 보고선 32다. 절대로 512일리가 없지

잊지말자.

CS, DS, ES, FS, SS 등등등 리얼모드에선 세그멘트 레지스터에 

16을 곱한뒤 범용레지스터 값과 더한걸 물리 메모리 주소로 쓴다.

즉 어셈블리에 

```nasm
mov si, 0x0020 
mov es, si
```

이런 코드가 있으면 뒤에 0하나 더 붙는다고 생각하자.

분명 기본적인거고, 봤던건데 잊고있었다.
