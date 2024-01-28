---
layout: post
title: JS array sort((a,b) => a < b) 가 정렬을 보장하지 않는 이유
date: 2024-01-29 00:00:00+0900
categories: development
comments: true
languages:
- korean
tags:
- Chromium
- V8
- Javascript
- crbug
---	


얼마 전에 crbug에서 기여할 항목을 찾다가 신기한 이슈를 발견했다.

https://bugs.chromium.org/p/v8/issues/detail?id=14595

![image](https://github.com/DevSDK/devsdk.github.io/assets/18409763/ac5b1d07-5dc2-4178-8d4c-f86768e5788b)


제보된 이슈의 내용을 요약하면 Array.prototype.sort의 동작과 TypedArray.prototype.sort 과 동작이 다르고, 다른 js 엔진과 compare function 동작이 다르다는 것이다. 이게 어떻게 된 일일까?

다음의 코드를 보았을 때 어떤 실행 결과를 기대하는가?

```javascript
[2,1,5,6,7].sort((a,b)=>(a<b))
```

얼핏 보기에는 정렬이 되기를 기대할 것이다.

하지만 결과는 `v8` 을 기준으로 정렬되지 않는다.

JSC, SpiderMonkey는 정렬을 해준다.

이 차이는 왜 발생할까?

ES15(2024) 표준을 살펴보면

![image](https://github.com/DevSDK/devsdk.github.io/assets/18409763/cf911834-9232-4e8a-8789-c8f351b45f00)


> 5. Let sortedList be ? **SortIndexedProperties(obj, len, SortCompare, SKIP-HOLES)**.

실질적으로 정렬을 수행하는 내용은 SortIndexedProperties 에서 수행하는 것으로 보인다.

해당 내용을 살펴보자. 

![image](https://github.com/DevSDK/devsdk.github.io/assets/18409763/978dd1d6-998c-4fc9-a802-ad81427c948f)


표준에서 abstract operation은 표준에서 쓰는 함수로 읽으면 편하다.

> 4. Sort items using **an implementation-defined sequence** of calls to SortCompare. If any such call returns an abrupt completion, stop before performing any further calls to SortCompare and return that Completion Record

여기서 주목할 단어는 implementation-defined다. 이 말은 구현 측에서 정의하도록 열어둔다는 뜻이다.

표준 내용을 조금 더 읽어보면 해당 implementation-defined 만족해야 할 내용이 있다. 

> * There must be some mathematical permutation π of the non-negative integers less than itemCount, such that for every non-negative integer j less than itemCount, the element old[j] is exactly the same as new[π(j)].
> * Then for all non-negative integers j and k, each less than itemCount, if ℝ(SortCompare(old[j], old[k])) < 0, then π(j) < π(k).

만족해야 할 내용을 요약하면 다음과 같다.

배열의 길이보다 작은 모든 정수 j, k가 있다고 할 때,

 a = arr[j], b = arr[k], compareFunction(a, b) 호출이  반환한 숫자가 0보다 작은 경우 a, b 순이여야 한다.


 다시 원래의 문제로 돌아가 보자

```javascript
[2,1,5,6,7].sort((a,b)=>(a<b))
```

compare 함수가 반환하는 값은 어떤 값일까?

false 혹은 true다. 이는 ToNumber 스팩에 의해서 최종적으로 0과 1을 소비하게 된다.

정렬을 수행하는 implementation-defined 이 요구하는 요구사항을 만족하는 값이 아니다. 따라서 이는 구현 측에서 결정이 되며 정렬을 수행하지 않는 것 또한 표준을 만족한다.

![image](https://github.com/DevSDK/devsdk.github.io/assets/18409763/eb7cc80d-9912-4c49-821e-15ad28230b1e)

따라서 이 이슈는 버그로 분류되진 않는다. 구글의 JS 리더 syg@의 더블체크를 받으면서 이슈를 닫았다.

