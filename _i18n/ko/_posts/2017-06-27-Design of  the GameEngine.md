---
layout: post
title: Comet Engine에 구현할 컨테이너의 구조를 대충 생각했다.
date:   2017-06-27 22:52:27		
categories: development
languages:
- english
- korean
tags:
- CometEngine
- GameEngine
- Container
- Library
- Optimazation
---		



최근에는 OS개발이 너무 재밌다 초반이라 그런가

그래서 엔진은 아마 잠깐 동결하지 않을까 싶은데..

물론 완전히 멈춰버린다는건 아니다. 오래걸리는거 빼고 천천히 만들어야지.

몇주는 쉬었다가, 다시 잡았다가 할수도 있겠다.

몇주는 많고 몇일? 정도려나. 아무튼

오늘은 엔진에 관심좀 주자하면서 고심했다.

일단 Visual Studio 상에서 나온 Custom Memory 부분의 Warnings을 제거했다.

c style casting을 static_cast 로 바꾸니까 케스팅쪽은 대부분 사라지더라

아무튼, 컨테이너라는 작지않은 라이브러리를 만들어야 한다.

그래서 코드대신에 UML을 대충 그렸다.

참고한건 Java의 컨테이너와 C#의 콜렉션이다.

C++ STL도 참고했음.

![이런구조](/uploads/2017-06-27/CometEngine/UML.png)

함수나 맴버는 아직 정해진게 없어서 뺌 이름도 사실 확정된건 아니다. 그냥 모양세만 나온듯..

나중에 종이에 그려가면서 고민해봐야겠다.

Iterator이나 그런 패턴들은 나중에 추가할꺼다.

아무튼 기왕 Custom Allocator도 만들었겠다, 컨테이너도 만들어야지.

아무래도 Custom Allocator은 크기가 제한되어있으니까. ( Memory block을 넣어줘야하니까)

뭔가 이걸 Wrapping해서 메모리 사이즈를 늘려주는 매커니즘을 하나 해야할꺼같다.

이것만 생각해도 머리아프네.

ArrayList쯤이야 그런건 손쉽겠지만, LinkedList 는... 대충 추상화해서 메모리 더 요구하는 그런코드는

하나로 묶든 해야겠다. 메모리 포인터가 바뀌게 되면 생기는 문제야 뭐...

사용자 측에서 데이터 Address 에 절대 접근 못하게 해야지.

아직 뼈대도 안나왔네 생각해보면

그리고 또 고민해야할껀 컨테이너 사에서 Thread-Safe함을 보장할껏인가.

흰머리 늘어난다.

이럼 또 느려질탠데.

대충 필요한 기능이나 이런걸 도출할 필요가 있겠다.

그건 나중에 해야하려나

STL은 영 뜯어보고 싶지가 않은 라이브러리라. 젠장 템플릿.

목표는 일단 STL보다 빠른거


근데 종종 엔진개발도 해야하는데.... 라는 생각이 들면 우울하다

OS 개발하고싶은데.

시간을 좀더 쪼개야겠다.
