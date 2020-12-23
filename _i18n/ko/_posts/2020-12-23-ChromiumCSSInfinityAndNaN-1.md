---
layout: post
title: Chromium CSS에 무한과 NaN 개념 도입하기 - 1
date:   2020-12-23 15:00:20
categories: Chromium
comments: true
languages:
- english
- korean
tags:
- Chromium
- C++
- Web Engine
- HTML/CSS
- InfinityAndNaN
- DevLog
---

Issue: [http://crbug.com/1076508](http://crbug.com/1133390)

Patches: 

1. [https://chromium-review.googlesource.com/c/chromium/src/+/2465414](https://chromium-review.googlesource.com/c/chromium/src/+/2465414)


현재 진행중인 프로젝트에 대한 활동 기록을 이 블로그에 적고자 한다.

아무래도 기능 추가에 관련된 이야기다 보니 글이 몇개로 나누어 질 것 같다.

이 글은 이 기능을 구현하면서 고민하고, 조사했던 내용을 담았다.

[https://developer.mozilla.org/en-US/docs/Web/CSS/calc()](https://developer.mozilla.org/en-US/docs/Web/CSS/calc())

css에는 calc라는 함수가 있다. 

이 함수를 CSS에서 직접 사용하면 다음과 같다.

```css
div {
	width: calc(10*2px);
}
```

위 결과는 20px값이 width에 반영된다.

앞으로 다룰 내용은 이 함수에 대한 기능 구현이다.

Chromium monorail에서 할만한 이슈를 찾던 중, 이 이슈가 눈에 들어왔다.

간결하디 간결한 이슈 본문을 보니 간단할 것 이라고 생각했다.


```
I'm told that per the spec, calc(1px/0) should compute to infinity and not be a parse error.

Testcase:
<div style="width: calc(1px/0); height: 10px; background: green;"></div>
http://plexode.com/eval3/#s=aekVQXANJVQMbAx1yAXgePQOCGwFEQk1ECRJRWRARChwBg50SEaWqi51IU0ZGTxyaHx0Qch8DXgA=
```

요약하자면 1px/0을 했을때 무한을 내놔야 합니다. 라는 내용이다.

이것이 이번 프로젝트의 발단을 알린 첫 이슈의 제시문이였다.

이슈가 제시되었을 때, 부랴부랴 표준 문서를 읽어보았다. 
CSS3와 MDN을 기준으로 "0으로 나누기는 무시되어야 합니다" 라고 쓰여있었다. 

그래서 이슈 제시자한테 표준에 따르면 나누기 0은 무시되어야 한다는데 출처 있니? 라고 물어보았고, 제시자는 "새로운 스팩 CSS Values and Units Module Level 4"를 참조로 알려주었다. 즉, 표준에 따르면 '무한', 'NaN' 개념을 calc 함수가 지원해야 했다.  그 답을 보자마자 이슈 owner를 박고 조사를 시작했다. 

처음으로 한 것은, calc 함수가 어디서 계산이 되는가를 찾는 것 이였다. 

기본적인 생각은 다음과 같았다. 

'calc 함수는 CSS 파서에 의해서 계산될 것' 

다음의 명령어를 치면 결과를 사람이 구별할 정도로 줄어든다.

그곳에서 parser 디렉토리 쪽 코드를 살펴보았다.

명령어를 좀 설명하자면 대소문자 상관 없이 'calc(' 문자가 매칭되는 test.cc가 아닌 .cc 파일로 끝나는 파일을 검색하여 리스트로 나타내라 이다.

```bash
grep 'calc(' -rni --include=*.cc --exclude=*test.cc
```

![1.png](/uploads/2020-12-23/1.png)

그중에서 눈에 띄는 주석이 있다.

이 글을 쓰면서 생각난 것 이지만, k'토큰이름' 으로도 검색할 수 있었다고 생각한다. (i.e. kCalc) 이는 크로미움에서 json5 파일을 통해 토큰 식별자를 자동생성하는 매커니즘 덕분에 떠올릴 수 있었다.


하여튼 저 곳을 들어가면,

![2.png](/uploads/2020-12-23/2.png)

이런 코드를 볼 수 있는데, 이 말은 kCalc 함수에 대하여 참조하는 곳을 찾아서 수식이 계산되는 곳을 찾으면 된다는 것 이다.

![3.png](/uploads/2020-12-23/3.png)

10개 남짓한 레퍼런스를 보며 소스코드를 보다보면 third_party/blink/renderer/core/css/css_math_expression_node.cc 코드 안에 관련 코드가 있음을 찾을 수 있다. (대부분의 코드는 이렇게 검색할 수 있다)

일단 calc 함수는 재귀적인 방식을 통해 괄호와, 사칙연산을 계산한다. 꽤 재밌는 부분인데 좀 간략히 설명하자면, parse 함수 호출→ Additive 함수 호출 → Multiplicative 함수 호출 → parse 함수 호출(재귀) 방식으로 사칙연산의 우선순위를 제공하고 있다.

사실 이러한 구현은, 웹 표준에서 정의하고 있다.

아래는 표준 문서에서 나타낸 식의 계산이다.

![4.png](/uploads/2020-12-23/4.png)

![5.png](/uploads/2020-12-23/5.png)


이 내용을 깊이 따라가는 것도 꽤 재밌는 일이다. [이곳이](https://source.chromium.org/chromium/chromium/src/+/master:third_party/blink/renderer/core/css/css_math_expression_node.cc;l=1101;drc=8b5f6ef28dd93e62fc1a75bc7a812af1b33777ec) 실제 소스코드를 따라가기 좋은 시작포인트라고 생각된다. 관심있으면 링크를 타고 가서 보길 바란다.


이제 시작점을 알았으니 값이 계산되는 부분을 찾고, 들어오는 문자열을 이용하여 infinity와 NaN을 구현하면 되는 것 이다.

 사실 첫 패치에선 NaN을 명시적으로 구현해야 함을 모르고 있었다. 따라서 코드리뷰를 통해 NaN 또한 추가되었다. 이번 포스팅에선 NaN을 다루는 이야기는 나오지 않을 것 이다.

함수 콜을 잘 따라가다 보면 이러한 함수에 도달한다.

![6.png](/uploads/2020-12-23/6.png)

즉 실질적인 계산을 담당하는 함수다.

무한을 구현하는 것을 정말 간단하게 생각하자면, case CSSMathOperator::kDivide: 에서 right_value가 0이라면 std::numeric_limits<double>::infinity() 를 리턴하면 되는 것 이라고 할 수 있다. 

따라서 다음과 같이 추가하였다.
![11.png](/uploads/2020-12-23/11.png)

또한 토큰에 대하여 

![7.png](/uploads/2020-12-23/7.png)

와 같이 infinity가 왔을때 해당하는 형식으로 반환하게 만들면 될 것 이라고 생각했다.

#### 테스트 작성

위 코드와 함깨 test 코드를 작성했다.

테스트 코드를 작성하면서 문제가 되었던 점은 round 함수가 없어 wpt 테스트가 실패하는 것과, blink_unittests 결과가 계속 실패하여 찾아보니 유닛테스트에는 다른 모듈을 이용하여 calc를 계산하고 있음이였다.

블링크 유닛테스트에는 calc 함수에 대해 다른 파서인 sizes_math_function_parser를 이용하여 파싱을 한다. 따라서 그에 해당하는 테스트인 sizes_math_function_parser_test.cc에서 테스트를 진행한다.

![8.png](/uploads/2020-12-23/8.png)

이 테스트는 'third_party/blink/renderer/core/css/parser/sizes_math_function_parser.cc' 안에있는 'CalcToReversePolishNotation' 함수를 통하여 파싱이되고 계산이 된다. 스택기반으로 작성되어 있다. 따라서 이곳에 우리가 필요했던 코드를 넣어줘야 했다. 
각각 무한을 스택에 집어넣는 AppendInfinity() 함수를 정의하여 사용하였다. 

다음은 스택에서 토큰을 만났을 때 문자열을 비교하여 infinity일시 무한을 집어넣는 코드이다.


```cpp
case kIdentToken:
        if (EqualIgnoringASCIICase(token.Value(), "infinity") ||
            EqualIgnoringASCIICase(token.Value(), "-infinity")) {
          AppendInfinity(token);
          break;
        }
        return false;
```

이를 통해 유닛테스트 부분은 해결할 수 있었다.

또한 blink_web_tests에 새로운 테스트 파일들을 추가하였다.

자바스크립트 기반의 테스트를 작성하였고, dumpAsText() (이 함수를 호출하면 -expected.txt 라는 파일의 렌더링 결과 텍스트와 비교한다. 간단히 말하면 화면에 나오는 텍스트를 덤프 뜨는것)를 사용하였다.

아래는 새로 추가한 blink/web_tests/css3/calc/calc-infinity.html 파일이다.

```html
<!DOCTYPE HTML>
<div id="dummy"></div>
<div id="results">Calc could handle an infinity value<br><br></div>
<script>
if (window.testRunner)
    testRunner.dumpAsText();

var tests = [
    "1px * infinity / infinity",
    "1px * 0 * infinity",
    "1px * (infinity + -infinity)",
    "1px * (-infinity + infinity)",
    "1px * (infinity - infinity)",
    "1px * infinity",
    "1px * -infinity",
    "1px * (infinity + infinity)",
    "1px * (-infinity + -infinity)",
    "1px * 1/infinity",
    "1px * infinity * infinity",
    "1px * -infinity * -infinity",
];

var results = document.getElementById("results");
var dummy = document.getElementById("dummy");
for (var i = 0; i < tests.length; ++i) {
    var expression = tests[i];
    dummy.style.width = 'calc(' + expression + ')';
    results.innerHTML += expression + " => " + dummy.style.width + "<br>";
}
</script>
```

위 결과는 blink/web_tests/css3/calc/calc-infinity-expected.txt 파일로 다음과 같이 저장되고 추후에 테스트에 사용된다.

```
Calc could handle an infinity value

1px * infinity / infinity =>
1px * 0 * infinity =>
1px * (infinity + -infinity) =>
1px * (-infinity + infinity) =>
1px * (infinity - infinity) =>
1px * infinity => calc(infpx)
1px * -infinity => calc(-infpx)
1px * (infinity + infinity) => calc(infpx)
1px * (-infinity + -infinity) => calc(-infpx)
1px * 1/infinity => calc(0px)
1px * infinity * infinity => calc(infpx)
1px * -infinity * -infinity => calc(infpx)
```


#### 패치 작성 
테스트와 소스코드를 추가한 한 뒤, 이렇게 완성한 패치를 git cl format을 통해 포멧팅을 하고, 소스코드를 정리하는 등 적절히 정리하여 아래와 같은 커밋메시지와 함깨  패치를 올렸다.  


![9.png](/uploads/2020-12-23/9.png)

![10.png](/uploads/2020-12-23/10.png)

여러 글로 나뉠 것 같았는데, 이번 글은 여기서 끊는게 맞을 것 같다.

다음 글에는 이 패치에 대한 코드리뷰, 그리고 그것에 대한 반영 부분일 듯 하다.