---
layout: post
title: JS 클로저는 표준에서 어떻게 다루고 있을까?
date: 2024-01-30 12:00:00+0900
categories: development
comments: true
languages:
- korean
tags:
- Chromium
- V8
- TC39
- ECMAScript
- Javascript
---	


클로저란 무엇일까?

간략하게 알고 있는 것은 outer function에서 선언한 요소를 inner function에서 접근 가능한 동작을 말한다는 것이었다.

> 왜 클로저라고 불릴까? [위키피디아에 따르면](https://en.wikipedia.org/wiki/Closure_%28computer_programming%29#History_and_etymology) Peter Landian이 1964 년에 그의 SECD 머신에서 사용되는 개념으로 클로저라는 용어를 처음 정의했다고 한다.

이 동작은 정확히 어떻게 보장받고 있는 걸까?

ECMA Script를 살펴보자. ES15(2024)를 기준으로 한다.

JS에서는 모든 함수는 Function object로 객체화된다.

여기서 사용되는 표준을 하나씩 살펴보자

함수가 객체화될 때 **[10.2.11 FunctionDeclarationInstantiation](https://tc39.es/ecma262/#sec-functiondeclarationinstantiation)** 라는 추상 연산에 의해 객체화가 된다.

여기서 추상 연산은 표준에서 사용되는 함수라고 생각하면 편하다.

그리고 \[[형식으로]] 표기된 공간은 internal slot이라고 불리는데 js에서는 노출 안되는 프로퍼티라고 생각하면 편하다.

### 함수는 객체다

실제로 함수가 선언되면서 객체화가 되는지 살펴보자.

[표준을 살펴보면,](https://tc39.es/ecma262/#sec-runtime-semantics-evaluatefunctionbody) 함수의 syntax 분석이 완료되면 syntax tree는 각각 타입에 맞게 떨어진다, 각각 FunctionBody, ConciseBody, GeneratorBody, AsyncFunctionBody, AsyncConciseBody로 등으로 부른다.

이 중에서 한 가지 케이스를 살펴보자.

```
FunctionBody : FunctionStatementList
1. Return ? **EvaluateFunctionBody** of FunctionBody with arguments functionObject and argumentsList.
ConciseBody : ExpressionBody
...이하생략

```

[15.2.3 Runtime Semantics: EvaluateFunctionBody](https://tc39.es/ecma262/#sec-runtime-semantics-evaluatefunctionbody) 표준을 따라가 보면, 해당 표준에서 드디어 위에서 언급한 연산이 호출되는걸 볼 수 있다.

```
FunctionBody : FunctionStatementList
1. Perform ? **FunctionDeclarationInstantiation**(functionObject, argumentsList).
2. Return ? Evaluation of FunctionStatementList.
```

자 그럼 실제 함수 선언이 이 연산을 통해 객체화가 된다는 사실을 알았다.

### 값 참조

클로저에 대해 더 알아보기 전에, 함수 내에서 값을 참조할 때 어떤 일이 일어나는지 살펴보자

값을 참조한다는 것은 함수 내의 assign 로직을 살펴보면 좋을 것이다,

**[13.15.2 Runtime Semantics: Evaluation](https://tc39.es/ecma262/#sec-assignment-operators-runtime-semantics-evaluation)** 표준을 살펴보면 assign 로직이 어떻게 평가되는지 알 수 있다. 평가되는 로직을 살펴보면 GetValue라는 연산을 호출하는 것을 알 수 있다.


![image](https://github.com/DevSDK/devsdk.github.io/assets/18409763/7fb97bcb-9bee-4b10-b946-5e3addfd2380)

**[6.2.5.5 GetValue](https://tc39.es/ecma262/#sec-getvalue)** 이 표준을 살펴보자.

![image](https://github.com/DevSDK/devsdk.github.io/assets/18409763/d2d06625-9a02-452a-8c05-b35ee483e829)

4.c를 잘 보면 GetBindingValue라는 연산을 수행하게 된다.

**[9.1.1.2.6 GetBindingValue ( N, S )](https://tc39.es/ecma262/#sec-object-environment-records-getbindingvalue-n-s)** GetBindingValue의 표준을 살펴보면 다음처럼 \[[BindingObject]] Internal Slot 값에서 가져온다는 사실을 알 수 있다!

![image](https://github.com/DevSDK/devsdk.github.io/assets/18409763/e0314236-85e6-433f-a6db-d16b841d7f22)

### 함수 객체화 표준: lexical scope에 접근한다

다시  함수가 객체화되는 곳을 살펴보자

![image](https://github.com/DevSDK/devsdk.github.io/assets/18409763/1477d678-99a7-4945-870e-057d180ac03f)

LexicallyScopedDeclareations of code를 돌면서 lexEnv에 값을 설정하는 것을 볼 수 있다.

그렇게 36.c 에 가면 **[9.1.1.2.5 SetMutableBinding ( N, V, S )](https://tc39.es/ecma262/#sec-object-environment-records-setmutablebinding-n-v-s)** 을 호출하게 되는데,


![image](https://github.com/DevSDK/devsdk.github.io/assets/18409763/103bd4d9-a191-4220-a472-2c295a39bc51)

위에서 서술했던 GetValue에서 사용하는 같은 internal 슬롯에 값을 쓰는 것을 볼 수 있다.

정리하자면 함수가 선언되며 객체가 되는데, 이 객체가 생성되는 과정에서 생성 당시의 Lexical Scope에 존재하는 선언을 함수 오브젝트의 internal slot \[[BindingObject]] 에 집어넣고, 함수 호출이 일어난다면 assign 등, 식별자의 값을 사용해야 할 때 해당 \[[BindingObject]]에 있는 값을 가져와서 활용하는 것이다.

```js
 // outer function object 생성, [[BindingObject]]은 global 스코프 내 정의된 값
function outer() {
  let test = 0
  // iner function object 생성, [[BindingObject]]에 들어있는 global 스코프에 정의된 값 + test
  return function inner() {
     // GetValue를 사용하여 [[BindingObject]]의 test값을 가져와 반환 후 값 증가
     return test++; 
  }
}

const func = outer()

//  0 출력. 왜냐하면 "[[BindingObject]]" 에는 outer 정보까지 다 들어있는 "객체"가 반환되기 때문
console.log(func())

// 1 출력. 왜냐하면 내부의 슬롯의 값이 업데이트되었기 때문
console.log(func()) 
```

우리는 이 일련의 동작 과정과 표준에서 보장하는 클로저 라는 기능을 사용하고 있다.

실제로 v8 구현체가 표준을 따르는지 간략히 살펴보았는데, 표준과 완전히 1대1 대응되진 않고, 전반적인 흐름이 표준을 만족하는 것으로 보인다.

아래는 큰 흐름에서 두 가지 지점이다.

[함수를 파싱하는 부분](https://source.chromium.org/chromium/chromium/src/+/main:v8/src/parsing/parser.cc;l=871;drc=25a9dc176029598d968de92e6cfd7dcb5e6246e4;bpv=1;bpt=1)

[런타임에서 값을 찾는 부분](https://source.chromium.org/chromium/chromium/src/+/main:v8/src/runtime/runtime-scopes.cc;l=798;bpv=0;bpt=1)

값을 사용하는 지점이 많다 보니 값을 찾는 부분을 명확히 전부 파악하기에 시간이 많이 소요될 것 같다. 