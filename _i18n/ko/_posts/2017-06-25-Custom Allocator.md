---
layout: post
title: Comet Engine에 들어간 Custom Allocator에 대한 이야기	
date:   2017-06-25 21:12:20		
categories: development
languages:
- english
- korean
tags:
- CometEngine
- GameEngine
- Memory
- Optimization
- 최적화
---		

한 2주 전 부터 고민하던 내용이였던

Costom Allocator 을 구현할까? 말까에 대한 내용인데,

System Allocator을 쓰면 C 에서는 malloc, C++에서는 new를 사용한다.
 
문제는 속도가 ms 단위로 빨라야 할 곳에 저것들은 느려 느리다고.

우선, Memory Allocation과정에서 발생하는 User-Kernel Mode 간의 

Context Switch 비용도 무시할 수 없을 뿐더러, 우리가 모르는 부가적인 코드를

함깨 실행시키곤 하며 느리게 동작한다.

그래서 정말 빨라야 할때 빠른 메모리 할당자가 필요하다면? 이라는 주제로 한동안 고민했다.

아예 안쓰는 방법도 있긴 있다.

전부 Stack에 선언해버리거나 하는등 말이다.

하지만 그건 싫다. 그렇게 고민하다가.

지나가다가 본 자료중에 흥미로운 구조들을 많이 발견했는데, 어떤 방식을 가져갈지 고민했다.

후보로는 Pool Based Memory Allocator, Stack Based Memory Allocator 그리고 아예 OS가 하는것 마냥

운영체제마냥 Paging Address 심고 세그멘테이션 해버리게 해볼까도 고민했었는데 나중에 free라던가, 

연속된 메모리 블록일경우라던가 고려할게 많았다.

그러다가 FreeList Based Allocator 자료를 보게 되었다.


		
![FreeList](/uploads/2017-06-25/CometEngine/Allocator/FreeList.gif)
 
Free List 는 대충 이렇게 생겼다.


간단히 말하면 

비어있는 메모리를 그 메모리를 이용해 Linked List로 만들고, 메모리를 할당할때 그 리스트에서 크기를 잘라 준다.

Free 하면 그 리스트에 이어버린다(물론 추가적인거로는 인접할경우 이전블록을 크게 키운다거나 하기도 함)

내부적으로는 

할당하면서 할당된 메모리 블록에 Header를 심는데, 16바이트 크기의 해더를 심고 사용자에게는 16바이트 이후의 주소를 준다.

즉 실제로 할당되는 크기는 요청 사이즈 + 해더 사이즈 + Align 유지를 위한 사이즈.

이렇게 해두면 Free 할때 해더정보를 읽어서 Free 할 수 있다.

Free 할땐 Header를 포함한 그 메모리 블록에 다시 FreeList Node를 심고 이어서 FreeList로 만듬.

간단함.

아무튼간 대충 이렇게 동작해먹는걸 내 엔진에 구현했다.

![Allocator](/uploads/2017-06-25/CometEngine/Allocator/CustomAllocation.PNG)

내부 구현 및 구조를 보고 싶으면 [여기](https://devsdk.github.io/CometEngine/html/namespace_comet_engine_1_1_core_1_1_memory.html)
서 보기 바람. (FreeListAllocator Class)

사용 방법은 다음과 같은데,

```cpp 
char* MemoryBlock = new char[1024 * 1024 * 10];
Memory::FreeListAllocator allocator = Memory::FreeListAllocator(MemoryBlock, 4, 1024 * 1024);

```

할당자의 대상이 될 메모리 블록을 선언한다.

그러곤 FreeListAllocator를 초기화 한다.

```cpp
allocator.alloc(size_t);
allocator.dealloc(void*);
```

각각 할당과

해제를 하는 함수다.

뭐 동작은 위 이미지에서 보듯 잘 된다.

게다가 Align 유지까지 됨.

만들었으니 빠르다는걸 검증을 해야지

나는 빠를것이다 라고 믿고있었고

테스트를 진행했다.

![Performance](/uploads/2017-06-25/CometEngine/Allocator/PerformanceTest.jpg)

테스트 조건은

배열크기 1000짜리 int 형 배열을 10000번 반복해 만들떄임.

( sizeof(int)*1000) iteration 10000 time. )

결과로 보듯

약 10배 차이난다.

| System Alloc | Custom Alloc | System Free | Custom Free |
|------------|------------|-----------|-----------|
|   0.0120 s |  0.0015 s  | 0.0091 s  | 0.0013 s  |


아무튼 빠르니까 기분 좋네.


나중에 Proxy 물려서 Profiler 넣든 하거나, Leak Management를 넣으면 좋을듯.

