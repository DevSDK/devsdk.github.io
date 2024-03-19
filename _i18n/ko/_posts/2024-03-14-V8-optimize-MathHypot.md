---
layout: post
title: V8의 Math.hypot 최적화 하기 - 반복의 숨은 비용
date: 2024-03-19 6:00:00+0900
categories: development
comments: true
languages:
- korean
- english
tags:
- Chromium
- V8
- TC39
- ECMAScript
- Javascript
- Optimization
---

## Introduction

Chrome, NodeJS 등 자바스크립트를 실행하는 런타임의  엔진인 V8에 구현되어 있는 javascript 함수 `Math.hypot` 의 속도를 약 200% 향상했습니다.

`Math.hypot` 함수는 거리를 계산하는 데 많이 사용되는 함수입니다.

> Hypotenuse = 빗변
>   <img  width="200" alt="image" src="https://github.com/DevSDK/devsdk.github.io/assets/18409763/d7a1ae04-c109-4734-a579-ca48d3f9cbdc"/>
>   <img  width="150" alt="image" src="https://github.com/DevSDK/devsdk.github.io/assets/18409763/17e4cfd6-31b8-4d43-b9dc-d944961ed907"/>


이 글에서는 성능 저하를 해결하기 위해 생각했던 가설과 속도 저하가 발생했던 원인 및 해결책을 소개할 것입니다.

CL: https://chromium-review.googlesource.com/c/v8/v8/+/5329686

## 과정

### 이슈 발견

V8의 이슈를 목록을 보던 중 삼각형의 빗변 길이를 계산할 때 사용하는 Math.hypot 함수가 곱셈 연산자 등을 활용하여 구현 한 것 보다 수십 배 느리다는 이슈를 발견했습니다.

처음에 이 이슈를 발견했을 왜 다른 빌트인 함수(Math.pow, **)를 사용한 것 보다 Math.hypot을 쓴 게 특별히 더 느릴까? 라는 생각을 했습니다.

아래는 이슈에 같이 첨부된 퍼포먼스 측정을 위한 코드입니다.


```ts
const n = 100_000_000

const methods = {
	'*': (a, b) => Math.sqrt(a * a + b * b),
	'hypot': Math.hypot,
	'**': (a, b) => Math.sqrt(a ** 2 + b ** 2),
	'pow': (a, b) => Math.sqrt(Math.pow(a, 2) + Math.pow(b, 2)),
}

Object.entries(methods).forEach(([name, method]) => {
	let a = Math.random() * 3, b = Math.random() * 91.3, c = 1

	let s = performance.now()

	for(let i = 0; i < n; i++){
		c += method(a, b)
	}
	
	console.log(`${name} took ${performance.now() - s}`)
})
```

실제로 이 코드를 실행하면 보면 곱셈(*)을 사용한 것과 상당한 차이가 난다는 것을 알 수 있습니다.


| Method | Runtime |
| --- | --- |
| * | 103.292ms |
| hypot | 1584.417ms |
| ** | 664.958ms |
| pow |  666.458ms |

### Math.hypot 구현체 살펴보기

`Math.hypot`함수는 [torque](https://v8.dev/docs/torque)라는 언어로 작성되어 있고, [src/builtins/math.tq](https://source.chromium.org/chromium/chromium/src/+/main:v8/src/builtins/math.tq;l=398-441;drc=8fcd3f809ba5c71f7a29bc6623c1f93a9eac72fe) 에 위치해 있습니다.

Torque는 타입스크립트와 비슷한 문법을 가진 V8내에서 사용하는 [언어입니다.](http://언어입니다.is)

```ts
// ES6 #sec-math.hypot
transitioning javascript builtin MathHypot(
    js-implicit context: NativeContext, receiver: JSAny)(
    ...arguments): Number {
  const length = arguments.length;
  if (length == 0) {
    return 0;
  }
  const absValues = AllocateZeroedFixedDoubleArray(length);
  let oneArgIsNaN: bool = false;
  let max: float64 = 0;
  for (let i: intptr = 0; i < length; ++i) {
    const value = Convert<float64>(ToNumber_Inline(arguments[i]));
    if (Float64IsNaN(value)) {
      oneArgIsNaN = true;
    } else {
      const absValue = Float64Abs(value);
      absValues.floats[i] = Convert<float64_or_hole>(absValue);
      if (absValue > max) {
        max = absValue;
      }
    }
  }
  if (max == V8_INFINITY) {
    return V8_INFINITY;
  } else if (oneArgIsNaN) {
    return kNaN;
  } else if (max == 0) {
    return 0;
  }
  dcheck(max > 0);

  // Kahan summation to avoid rounding errors.
  // Normalize the numbers to the largest one to avoid overflow.
  let sum: float64 = 0;
  let compensation: float64 = 0;
  for (let i: intptr = 0; i < length; ++i) {
    const n = absValues.floats[i].ValueUnsafeAssumeNotHole() / max;
    const summand = n * n - compensation;
    const preliminary = sum + summand;
    compensation = (preliminary - sum) - summand;
    sum = preliminary;
  }
  return Convert<Number>(Float64Sqrt(sum) * max);
```

### 가설 1: Allocate가 느린가?

먼저, 메모리를 할당/해제 반복적으로 한다면 메모리 관리 비용으로 인해 느려질 것으로 추정했습니다.

이 가설을 테스트하기 위해 메모리를 할당하는 구문(`AllocateZeroedFixedDoubleArray`) 을 제거하고 arguments를 직접 사용하게 변경했습니다.

그러나, 퍼포먼스가 드라마틱하게 증가하진 않았습니다.

### 가설 2: ToNumber_Inline 의 비용이 높은가?

ToNumber [표준을 보면](https://tc39.es/ecma262/multipage/abstract-operations.html#sec-tonumber) 다양한 경우를 분기 처리하고 있어 비용이 비용이 클 수 있다는 가설을 세웠습니다.

이 가설이 맞는지 테스트 하기 위해 파라미터의 값이 Number 타입인지 체크하고, Float64로  UnsafeCast하여 테스트를 진행했습니다.

성능 향상이 0.5~2% 대로 미미했기 때문에  이 가설은 문제의 핵심 원인이 아니라고 판단했습니다.

### 가설 3: 부차적인 연산의 비용이 높은가?

위 구현을 보면 빗변을 계산하는 구문 이외에 절댓값으로 변환하거나 것과 [Kahan summation](https://en.wikipedia.org/wiki/Kahan_summation_algorithm) 알고리즘을 수행하는 등 별도의 연산이 포함되어 있습니다.
저는 이 부차적인 연산이 성능에 영향을 줄 것 이라는 가설을 세웠습니다.

이러한 알고리즘 구현을 제거하고, 테스트하기 위해 위 함수 상단에 파라미터가 2개인 경우 `sqrt( a ^ 2 + b ^ 2)` 만 계산하도록 구현하고 테스트 해봤습니다.

```ts

  if (length == 2) {

	  let max: float64 = 0;

    const a = Convert<float64>(ToNumber_Inline(arguments[0]));
	  const b = Convert<float64>(ToNumber_Inline(arguments[1]));

    if (a == V8_INFINITY || b == V8_INFINITY) {
      return V8_INFINITY;
    }

    max = Float64Max(a, b);

    if (Float64IsNaN(max)) {
      return kNaN;
    }

    if (max == 0) {
      return 0;
    }

    return Convert<Number>(
        Float64Sqrt((a / max) * (a / max) + (b / max) * (b / max)) * max);
}
```

테스트 결과 놀라울 만큼 빨라졌습니다.

| Method | Runtime |
| --- | --- |
| * | 104.041ms |
| hypot | 104.041ms |
| ** | 670.709ms |
| pow | 674.583ms |

위 구현은 간단하게 구현하기 위해 arguments 길이가 2인 경우에만 실행되도록 구현했습니다.

위 테스트에 이어서 위 길이가 2인 경우만 계산하는 로직을 제거하고, 아래에 있는 구현에 부차적인 연산을 제거하는 테스트를 수행했습니다.

그러나 이번 테스트에서는 다시 속도가 느려졌습니다.

따라서,  부차적인 로직을 제거한 것이 빨라진 것의 원인이라고 보기는 어려울 것 입니다.

## 현상 분석: 왜 빨라진 것 인가

이제 성능이 향상되는 현상을 발견했습니다. 

이 현상의 원인을 설명할 수 있다면 이 최적화에 대한 CL(PR과 같은 개념입니다)을 제출할 수 있을 것입니다.

우선 코드에서 크게 사라진 부분이라고 한다면, 반복문일 것입니다. 

반복문이 원인일 가능성이 높아진 상황에서 실험을 해보기로 합니다. 아래의 코드를 Math.hypot 구현체에 추가 했습니다.

```ts
for(i = 0; i<length; i++) {
}
```

위 코드의 삽입으로 200ms 의 지연이 발생 했습니다.

이 현상에 대해 두 가지의 가설을 세워 검증했습니다.

### 가설 4:  torque로 작성되어 CSA로 컴파일된 loop는 비효율적인가?

이 가설은 “CSA([Code Stub Assembler](https://v8.dev/blog/csa))로 컴파일 되는 torque는 CSA로 직접 구현한 것 보다 for loop 동작이 느리게 수행된다”는 가설입니다.

마치 어셈블리로 직접 구현 하면 일부 구간에선 빠르게 동작할 수 있는 것처럼, 이 가설을 검증하기 위해 CSA로 직접 구현해 비교해 보기로 합니다. 

CSA로 구현하여 비교한 결과 평균적으로 아주 약간 빠른걸 알 수 있었습니다.


<img  width="512" alt="image" src="https://github.com/DevSDK/devsdk.github.io/assets/18409763/1528ff51-3c0c-4fb1-a6a9-dcae57999cda"/>

그러나 이 차이는 미미하기 때문에 성능 저하의 핵심 원인은 아닐 것입니다.

### 가설 5 및 결론 : Loop의 숨겨진 cost가 있는가?

반복문의 유무로 큰 차이가 발생하는 이유에 대해 면밀히 고민해 보다가 낸 결론입니다.

반복문에는 숨겨진 비용이 존재합니다.

반복문의 진입 시 비교하고, 반복 탈출을 위하여 n 번 즉 n+1, 증가 연산도 마찬가지로 반복문 내에서 n번 실행되게 됩니다. 

다시 `Math.hypot` 구현체로 돌아가 살펴보면, 총 두 개의 반복문이 있는 것을 알 수 있습니다.

그렇다면 파라미터가2개일 때 6번의 비교 연산과 4번의 증가 연산이 반복문을 위해 소비되고 있음을 알 수 있습니다.

여기서 실행 횟수 N이 커지게 될 경우 N * 6 만큼 연산량이 소비될 수 있으며 이에 따라 실행시간이 차이 난 것입니다.

## 개선

따라서, 파라미터의 길이가 3보다 작은 경우 반복문 없이 실행되도록 하여 최적화를 했습니다.

이 과정에서 파라미터가 3개인 경우에는 [Kahan summation](https://en.wikipedia.org/wiki/Kahan_summation_algorithm) 알고리즘을 방정식으로 정리하여 적용했습니다.

```ts
  try {
    return FastMathHypot(arguments) otherwise Slow;
  } label Slow {
    const length = arguments.length;
// ...
```

`FastMathHypot`의 전체 구현체는 [여기서](https://chromium.googlesource.com/v8/v8/+/2cfc118b6d316f90b4e6c167deeab43d39588522/src/builtins/math.tq#398) 살펴보실 수 있습니다.

## 결론

아래는 최적화 이후 실행 시간입니다. 


| Method | Runtime |
| --- | --- |
| * | 104.041ms |
| hypot | 104.041ms |
| ** | 670.709ms |
| pow | 674.583ms |



위 결과에서 볼 수 있듯 최적화 이전 실행시간(1584.417ms) 대비 약 194% 향상되었음을 알 수 있습니다.

여러 번 실행해 본 결과 180~200%의 성능 향상 폭을 얻었음을 알 수 있었습니다.

이번 최적화에서는 메모리의 할당부터, ToNumber, 부차적인 연산, For loop와 관련된 가설을 세웠습니다. 이 가설들을 검증해 가며 for loop 관련 가설이 옳은 가설임을 알게 되었습니다. 여기서 loop의 숨겨진 비용을 찾아냈고 그 비용을 제거하여 V8을 개선했습니다.

여기서 배울 수 있었던 점은 반복문에는 반복문 자체를 위한 비용이 있고, 이 비용은 상황에 따라 큰 오버헤드로 작용할 수 있다는 점이겠습니다.



마지막으로,

이 글을 퇴고 해주신 [김현영 님께](https://www.atobaum.dev/) 감사인사 드립니다.
