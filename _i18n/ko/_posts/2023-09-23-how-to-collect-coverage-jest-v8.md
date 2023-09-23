---
layout: post
title: Jest는 Code Coverage를 어떻게 측정할까? (V8)
date:   2023-09-23 00:00:01
categories: development
comments: true
languages:
- english
- korean
tags:
- Chromium
- V8
- Javascript
- Jest
---
## Motivation

회사에 커버리지를 중심으로 한 워크플로우를 만들고자 하는데 커버리지가 정확히 무엇인지 알고자 했다.

## Introduction

이 글을 통해서 `jest --CollectCoverage --coverageProvider=v8`는 어떻게 커버리지를 측정하는지 jest 를 시작으로 가볍게 v8을 살펴보며 커버리지를 어떻게 측정하는지 알게 될 것이다.

컴파일러 이론을 미리 알고 보면 더 읽기 수월할 것이다.

## Coverage?

> [소프트웨어 공학](https://en.wikipedia.org/wiki/Software_engineering)에서 **코드 커버리지**는 특정 Test Suite가 실행될 때 프로그램의 **소스 코드**가 실행되는 정도를 백분율로 측정한 것이다 - 위키피디아
> 

우리는 jest를 통해서 코드를 테스트하고 있으며 `—CollectCoverage` 옵션을 통해 테스트 커버리지를 측정할 수 있다.

```jsx
export function testFunc(a: number, b: number) {
  if (a > 20) {
    return 0;
  }
  return a + b;
}
```

```jsx
import { testFunc } from "~/hooks/func";

it('test', ()=> {
  expect(testFunc(10, 20)).toBe(30);
})
```

![Untitled](/uploads/2023-09-23/coverage.png)

---

## Coverage in jest

이 커버리지는 어떻게 측정하고 있는 걸까? 그리고 무엇일까?

V8을 기준으로 설명해 보고자 한다.

Jest는 내부적으로 [collect-v8-coverage](https://github.com/SimenB/collect-v8-coverage) 패키지를 쓴다

내부 구현체를 보면 

```jsx
async startInstrumenting() {
    this.session.connect();

    await this.postSession('Profiler.enable');

    await this.postSession('Profiler.startPreciseCoverage', { // Start
      callCount: true,
      detailed: true,
    });
  }
```

Start로 표현된 `Profiler.startPreciseCoverage` Chrome Devtools Protocol을 사용하여 커버리지 측정을 진행한다.

이는 V8의 커버리지 측정 기능을 활용하기 위해 V8에 요청을 보내는 명령어로 아래의 링크에서 구체적인 내용을 확인 할 수 있다.

https://chromedevtools.github.io/devtools-protocol/tot/Profiler/

커버리지는 저 옵션을 통해 가져오게 되는 걸 알게 되었다.

구체적으로 저 프로토콜을 활용해 어떻게 커버리지를 측정하고 있을까?

아래는 해당 프로토콜을 이용해 아래 “test 함수의” 커버리지를 계산하는 예제다.
```jsx

const { Session } = require("inspector");

const { promisify } = require("util");

global.session = new Session();
const postP = promisify(global.session.post.bind(global.session));

async function main() {
  global.session.connect();
  await postP("Profiler.enable");

  await postP("Profiler.startPreciseCoverage", {
    callCount: true,
    detailed: true,
  });

  function test(a, b) {
    if (a > 20) {
      return 0;
    }
    return a + b;
  }

  let l = 10;
  var v = 20;

  console.log(test(l, v));

  console.log(test(l, v) === 30);

  console.log(test(l + 20, v) !== 20);

  const r = await postP("Profiler.takePreciseCoverage");

  await postP("Profiler.stopPreciseCoverage");
  await postP("Profiler.disable");

  const file = r.result.find((f) => f.url.startsWith("file://"));
  console.log(JSON.stringify(file, null, 4));
}

main();
```

이 코드를  nodejs환경에서 실행하면 다음의 결과를 콘솔에 출력할 것이다.

```
{
    "scriptId": "481",
    "url": "file:///Users/seokho/workspace/chromium/playground/v8_test.js",
    "functions": [
        {
            "functionName": "main",
            "ranges": [
                {
                    "startOffset": 182,
                    "endOffset": 777,
                    "count": 1
                }
            ],
            "isBlockCoverage": false
        },
        {
            "functionName": "test",
            "ranges": [
                {
                    "startOffset": 372, // byte offset
                    "endOffset": 454,
                    "count": 1
                },
                {
                    "startOffset": 409,
                    "endOffset": 431,
                    "count": 0
                }
            ],
            "isBlockCoverage": true
        },
        {
            "functionName": "",
            "ranges": [
                {
                    "startOffset": 699,
                    "endOffset": 729,
                    "count": 0
                }
            ],
            "isBlockCoverage": false
        }
    ]
}
```

여기서 볼 수 있듯이 몇 번 호출되었는지 블록 커버리지인지 여부를 포함한 정보를 소스레벨에서 조회할 수 있게 된다. offset은 바이트 단위로 소스코드 내에서의 위치 정보를 알 수 있다.

---

## Compiler overview

아래 내용은 컴파일러의 동작에 대한 대략적인 이해가 있다면 더 이해하기 수월할 것이다.

아래 이미지를 통해 간략히 설명하고 넘어갈 것이다.


![Untitled](/uploads/2023-09-23/v8.png)


컴파일러는 다양한 파이프라인을 가지고 있는데 소스코드를 받아 중간의 AST를 구성하게 된다. 

![Untitled](/uploads/2023-09-23/ast.png)


이 AST를 이용하여 (v8 turboshaft)IR; Intermediate Representation을 만드는데 여기까지를 컴파일러의 프론트엔드라고 부른다.

만들어진 IR을 입력으로 받아 목적코드를 만들거나 바이트코드를 생성하는 단계를 컴파일러의 백엔드라고 불린다. 이를 통해 소스코드가 VM과 네이티브 머신에서 실행될 수 있는 형태로 변화하는 것이다.

정리하자면, 코드를 트리로 만들고 트리를 중간 표현식으로 만들고, 중간 표현식을 통해 목적코드를 생성하는 과정을 거쳐 컴파일러는 코드를 컴파일한다.

---

## How to check coverage in V8

그렇다면 이를 실행시켜주는 V8은 이 실행 여부를 어떻게 계산하고 있을까?

V8은 두 가지 방식으로 커버리지를 측정할 수 있게 지원한다.

1. Best effort
    1. 실제 실행 성능에 큰 영향을 주지 않지만 GC등에 의해 데이터를 잃을 수도 있다.
        1. [Profiler.getBestEffortCoverage()](https://chromedevtools.github.io/devtools-protocol/tot/Profiler/#method-getBestEffortCoverage)
2. Precise coverage insurance
    1. GC로 데이터를 잃지 않고 정확한 실행 횟수 등을 얻을 수 있지만 실행 성능 등에 영향을 받을 수 있다.
        1. [Profiler.startPreciseCoverage(callCount, detailed)](https://chromedevtools.github.io/devtools-protocol/tot/Profiler/#method-startPreciseCoverage)

Best-effort coverage v8의 메커니즘을 활용하는 방식이다.

첫 번째로 호출 카운터라고 불리는 요소를 이용한다.

함수는 각각 v8의 ignition 인터프리터를 통해 호출되는데 함수가 호출될 때 마다 feedack vector의 호출 카운터를 증가시키도록 하는 방법이다.

두 번재는 재활용 메커니즘은 “함수의 소스 범위를 알아내는 것이다.

커버리지를 기록하고자 할 때 호출 카운터는 어떤 파일과 연관되는지 정보가 필요하다. 이때 [Function.prototype.toString](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function/toString)을 통해 함수의 위치를 알아낸 뒤, 부분 문자열을 추출해 내부적으로 함수의 시작과 끝 지점을 알 수 있다.

따라서 Best Effort 커버리지 측정 방식은 실행 환경에서 사용되는 부산물(?) 들을 재활용해 특정하는 방식이기 때문에 성능상 영향이 적다.

하지만 대략적인 커버리지를 알 수 있으며 GC나 기타 최적화에 의해 가려지기도 한다는 단점이 있다.

Precise coverage는 Block 단위 커버리지라고도 불리는데, 이는 각각의 expression block에 대한 커버리지를 한다는 이야기가 된다. 예를 들어 if 절의 than 블럭과 else 블럭에 대한 각각의 측정을 한다는 것이다.

Best effort도 호출 카운터를 이용하기에 오해할 수 있는데, 그때 사용되는 호출 카운터는 소스 범위만을 특정할 수 있어 블럭 단위의 정밀한 측정을 이야기하는 것은 아니다.

Precise Coverage 측정은 v8 컴파일러가 AST를 분석하면서 Conditional Block을 Bytecode generation 할 때 IncBlockCounter 명령어를 집어넣는다. 이 명령어가 실행되냐에 따라 Call count를 도출할 수 있고, 이를 통해 블럭단위의 커버리지를 측정할 수 있는 것이다.

---

## See with example

이번 단락에서는 위에서 설명한 개념이 어떻게 실제로 동작하는지 볼 것이다.

다음 함수에 대해

커버리지를 측정한다고 가정해본다.

```jsx
function test(a, b) {
    if(a > 20) {
      return 0
    } 
    return a + b;
  }
  
  let l = 10
  var v = 20

console.log(test(l,v))

console.log(test(l, v) === 30)

console.log(test(l + 20, v) !== 20)
```

V8 컴파일러 프론트엔드는 이 코드를 파싱하면서 AST를 구성할 것이다.

아래 명령어를 통해 위 코드의 AST를 출력해보자.

`./d8 --print-ast ~/workspace/chromium/playground/test.js`

```dart
[generating bytecode for function: test]
--- AST ---
FUNC at 13
. KIND 0
. LITERAL ID 1
. SUSPEND COUNT 0
. NAME "test"
. PARAMS
. . VAR (0x158832470) (mode = VAR, assigned = false) "a"
. . VAR (0x1588324f0) (mode = VAR, assigned = false) "b"
. DECLS
. . VARIABLE (0x158832470) (mode = VAR, assigned = false) "a"
. . VARIABLE (0x1588324f0) (mode = VAR, assigned = false) "b"
. IF at 24 // BLOCK
. . CONDITION at 29 // BLOCK
. . . GT at 29 // BLOCK
. . . . VAR PROXY parameter[0] (0x158832470) (mode = VAR, assigned = false) "a"
. . . . LITERAL 20 // BLOCK
. . THEN at -1 // BLOCK
. . . BLOCK at -1 // BLOCK
. . . . RETURN at 41 // BLOCK
. . . . . LITERAL 0 // BLOCK
. RETURN at 57// BLOCK 
. . ADD at 66
. . . VAR PROXY parameter[0] (0x158832470) (mode = VAR, assigned = false) "a"
. . . VAR PROXY parameter[1] (0x1588324f0) (mode = VAR, assigned = false) "b"
```

AST의 Block으로 표현한 부분이 함수의 블럭, 조건 등에 의한 한 **블럭들이** 될 것이다.

그러면 위 AST를 통해 만들어진 결과물은(IR; Intermediate Representation)은 컴파일러의 백엔드로 전달되어 아래와 같은 바이트코드를 만들어 낼 것이다. (아마도 IR 표현에는 해당 로직이 포함되어 있을 것이다.)

아래는 컴파일러가 해당 AST, IR을 전달받아 생성한 목적코드인 Bytecode (VM의 어셈블리어)다.

`node --print-bytecode --print-bytecode-filter="test" ~/workspace/chromium/playground/v8_test.js`

```jsx
seokho@Dave ~/workspace/chromium/src/out/Default % node --print-bytecode --print-bytecode-filter="test" ~/workspace/chromium/playground/v8_test.js
[generated bytecode for function: test (0x00a7d39a6811 <SharedFunctionInfo test>)]
Bytecode length: 21
Parameter count 3
Register count 0
Frame size 0
OSR urgency: 0
Bytecode age: 0
  385 E> 0xa7d39b8b88 @    0 : b3 00             IncBlockCounter [0]
  398 S> 0xa7d39b8b8a @    2 : 0d 14             LdaSmi [20]
  403 E> 0xa7d39b8b8c @    4 : 6e 03 00          TestGreaterThan a0, [0]
         0xa7d39b8b8f @    7 : 99 06             JumpIfFalse [6] (0xa7d39b8b95 @ 13)
         0xa7d39b8b91 @    9 : b3 01             IncBlockCounter [1]
  417 S> 0xa7d39b8b93 @   11 : 0c                LdaZero
  425 S> 0xa7d39b8b94 @   12 : a9                Return
         0xa7d39b8b95 @   13 : b3 02             IncBlockCounter [2]
  437 S> 0xa7d39b8b97 @   15 : 0b 04             Ldar a1
  446 E> 0xa7d39b8b99 @   17 : 39 03 01          Add a0, [1]
  450 S> 0xa7d39b8b9c @   20 : a9                Return
Constant pool (size = 0)
Handler Table (size = 0)
Source Position Table (size = 19)
0x00a7d39b8ba1 <ByteArray[19]
```

명령어 `IncBlockCounter` 가 블록에 추가된 것을 확인할 수 있다.

`IncBlockCounter(slot)` 명령어는 해당 블록 슬롯의 call counter를 증가시킨다.

이 정보를  devtools protocol을 통해 결과로 가져온 것이 첫 단락에서의 커버리지 데이터인 것이다.

---

### References

https://v8.dev/blog/javascript-code-coverage

https://chromedevtools.github.io/devtools-protocol/tot/Profiler/#method-startPreciseCoverage

https://docs.google.com/document/d/1wCydi2HEZRF0skDeLb6CH0abZnTyVo5Vz5u-jhwi7es/mobilebasic

I’m flattered to be the first beta reader. good to know how jest ( or collect-v8-coverage, even or Profiler) calculate coverage and how and when V8 compiler helps. thanks