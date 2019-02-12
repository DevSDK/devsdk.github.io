---
layout: post
title: 그 어느 서적을 읽던, 이상하다 싶으면 오탈자인지 찾아보셔야 합니다.
date:   2017-06-26 22:52:20		
categories: development
languages:
- english
- korean
tags:
- 0SOS
- OS
- Operating System
- System
- function
---		

OS 책 읽으면서 (64비트 멀티코어 OS 원리와 구조) 설명을 읽고, 내 지식을 가지고

example code를 한참 들여다 보았다.

149쪽 함수 호출쪽.

그 이유는 스택 프레임에서 함수 안에는 변수 하나밖에 없는데, 스텍포인터를 8바이트나 내려버렸다.

뒷 내용도 그래서 뭔가 이상했다.

그래서 좀 더 찾아보고 오탈자 여부를 찾아보고 커뮤니티같은곳에 가서 확인해본 결과

저자분게서 Visual Studio 상에서 나온 코드를 바로 넣어서 그렇게 나왓다고 하신다.

분명 VS가 뭔짓을 한게 분명해.

아무튼 한참 들여다 본 코드는

```c
    int Add(int a, int b, int c)
    {
        return a+b+c;
    }
    void main()
    {
        int Result;
        Result = Add(1,2,3);
    }

```

나도 안다 void main은 표준이 아닌거. 책에 이렇게 써있음.

이 코드가 어셈블리로

```nasm
Add:
    push ebp
    mov ebp, esp
    
    mov eax, dword[ebp + 8]

    add eax, dword[ebp + 12]
    add eax, dword[ebp + 16]

    pop ebp
    
    ret 12

main:
    push ebp
    mov evp, esp

    sub esp, 8

    push 3
    push 2
    push 1
    call Add
    mov dword[ebp - 4],eax
    ret
```

이렇게 변한다고 써있다. 문제가 됬던건 main 함수에서 3번째 그리고 마지막에서 위로 2번째 

```nasm
sub esp, 8


mov dword[ebp - 4], eax
```

스택프레임에서 남은 4바이트는 어디로 사라지는건가 했다.

뭔가 안에서 필요한건지, 아님 단순 오타인지 모르겠다. 아무튼

분명 c코드에는 변수 하나밖에 없는데 왠 8바이트인가 했다.

예전에 컴파일러 공부했을때도 그냥 변수당 size를 스택에 할당 해서 넣던데, 뭔가 이상했다. OS개발할땐 또 다른가

아냐 그럴리가 없어 하면서 스택프레임에 뭘 더 집어넣나 해서 보니까 그런거도 아님

찾아보니까 저자분께서 VS에서 내놓은 바이너리를 역어셈블리해서 나온코드를 넣으셔서 저렇게 들어갔다고 한다.

아무튼간, 정말 재대로 된 코드는 아마도 

```nasm
sub esp, 4


mov dword[ebp], eax
```

가 아닐까 싶다.

찾아보니까

[저자분께서 맞다고 하신다](http://jsandroidapp.cafe24.com/xe/6311#comment_6377)

아무튼 또 하나 해결