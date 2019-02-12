---
layout: post
title: QEMU + GDB로 디버깅 환경 조성
date:   2017-07-03 12:40:20		
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
- Debug
- 64bit
---		

현제 작성중인 OS는 Ubuntu (Windows Bash) + Vim 으로 개발 중이다

지금까진 감당하기야 하겠는데, 점점 프로그램이 커지면 디버깅 도구가

필요할 듯 했다.

QEMU 자체에도 어느정도의 디버깅이 가능하게끔 해뒀지만,

전문 디버거를 사용하는 것 보단 부족할 것이다.

전에, 메모리에 재대로 데이터가 들어오는가에 대해 알아보기 위해 해당

기능을 사용했었는데, 컨트롤 알트 + 2 로 qemu 콘솔에 들어가서

x [주소]로 메모리에 있는 데이터를 볼 수 있다.

그걸로 어찌어찌 해결 보긴 했지만, 바로 이전 글에서 성공한 64비트

커널 엔트리를 만들면서 디버거의 도움이 있었다면 더 빠르게 만들 수 있었을 것 이라고 생각이 들었다.

보니까, qemu 자체에서 gdb host를 하는 기능을 지원한다.

qemu 실행 옵션으로 

```
-gdb tcp::[prot]
```
를 주면 된다. 물론 포트는 원하시는 걸로..

그리고 gdb 측에선 

gdb를 실행하고

```
(gdb) target remote tcp::[port]
```
를 하게 되면 연결이 된다.

이상태로도, 어느정도의 디버깅은 가능하다.

메모리를 직접 다루는 구문등 말이다.

```
(gdb) break *0x200000
```
로 브레이킹 포인트를 해당 어드레스에 지정하고
```
(gdb) continue
```
하면 그 어드레스를 실행할때 브레이킹을 걸고 디버깅 콘솔로 넘어간다.

![memory](/uploads/2017-07-03/OS/AddressBreaking.png)



하지만 심볼데이터가 없기때문에, 특정 구문, 함수에서 멈추거나 할 수 없기에

반쪽짜리 느낌이다.

많은 기능을 못 쓰고, list 같은거도 못쓴다.

심볼을 추가하기 위해선

일단, OS를 빌드하는 makefile에서 gcc 구문에 -g를 추가해 준다.

그럼 빌드 되었을때 디버깅 정보가 같이 들어간다.

![debuging](/uploads/2017-07-03/OS/DebugInfo.png)

그림은 링킹이 끝난 .elf 파일을 objdump로 열어본 결과이다.

그럼 그걸 gdb 실행시 연결하면 된다

```

gdb -s [경로]

```

링킹이 끝난 .elf 파일을 지정해 줘도 된다.

뭐 나같은 경우 64비트 커널에서만 개발 할 것으로 생각되기에 

02_Kernel64/Obj/Kernel64.elf

로 지정해 주었다.

그러니까 

![잘 됨](/uploads/2017-07-03/OS/64BitKErnelSymble.png)

함수 이름으로 브레이킹 포인트를 걸 수 있다.

그리고 Continue로 진행하고 

해당 지점에 도달했을때

```
list

```
를 입력해 보았다.

![역시아주 잘 댐](/uploads/2017-07-03/OS/GDBList.png)


이제 디버깅 환경이 구성되었다.

GDB 처음 써보는데, 잘 쓸 수 있을지 걱정이긴 하다.

혹시 qemu와 gdb를 연결해 디버깅 해야 할 사람이라면, 이 글이

도움이 되었길 바란다.

이제 본격적인 OS개발 시작~!
