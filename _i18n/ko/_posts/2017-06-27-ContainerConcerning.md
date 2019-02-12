---
layout: post
title: Comet Engine에 만들 컨테이너 라이브러리 고민
date:   2017-06-27 18:42:27		
categories: development
comments: true
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



이번 엔진은 정말 느릿느릿, 재대로 만들꺼다. 

그렇다보니 빨랐으면 하고, 견고했으면 한다.

그것의 첫걸음으로 엔진 자체에서 Custom Allocator를 제공한다.

[여기서 해당 내용을 볼 수 있다](https://devsdk.github.io/development/2017/06/25/Custom-Allocator.html)

아무튼간, 정말 Low-Level 하부 시스템부터 에디터까지 천천히 만들까 한다. 물론 계획된 개발 기간도 없음.

(예상으론 2년 넘게 걸리지 않을까 싶다.)

두번째 걸음으로는 이제, 데이터 컨테이너 라이브러리 제공을 위한

컨테이너의 설계 및 구현이겠다.

이것도 버전을 두개로 나눠버릴까 싶다.

Custom Allocator를 쓰는 버전과, System Allocator를 쓰는 버전으로.


STL보단 빠를거다. 물론 동일한 알고리즘 안에서는

그리고, 추후에 수정 보완이 더 손쉬울꺼라고 믿는다.

고민중인건 Custom Allocator를 쓰는 버전에 접두사를 붙일까말까

C를 붙여볼까 고민해봤다.
```cpp
CArrayList<int>
```

뭔가 안이뻐보이면서도 엔진 이름하고 절묘하게 맞네

시스템 얼로케이터 쓰는곳은 그냥 접두사 없이 해놔야지

아마 시스템 얼로케이터로는 VirtualAlloc를 쓸거같다.

네임스페이스도 나름 고민중인데  아마 쓰게될 후보는

```cpp
CometEngine::Core::Container::C //Custom Allocator
CometEngine::Core::Container::S //System Allocator
```
혹은 S나, C 가 없는 버전이 되겠다.

저안에 이제 열씸히 Class 화 시켜서 구조화 시켜야지

급한거 아니니까 정말 천천히 고민해가면서.

대충 STL 뜯어봐야겠다.



## 추가

아 그러고보니까 젠장, Thread-Safe 하게 만들어야 하는구나.

안그래도 많은 흰머리 늘겠네.