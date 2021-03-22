---
layout: post
title: double 형의 "계산 가능한 범위" 그리고 chromium의 maximum angle 
date:   2021-03-22 00:00:01
categories: development
comments: true
languages:
- korean
tags:
- Chromium
- Chrome
- ieee 754
---	

Chromium, CSS Math Function 에 \<angle>의 무한 값을 도입하면서 삽질한 기록이다.

삽질을 하게 된 계기는 표현한 최댓값이 "계산 가능한" 값인 줄 알았던 것이다.

또한 현재 코드리뷰는 진행중이기 때문에 값은 얼마든지 변할 수 있다.

하지만 매커니즘이 변하진 않을 것 같다.

Review: [https://chromium-review.googlesource.com/c/chromium/src/+/2774851](https://chromium-review.googlesource.com/c/chromium/src/+/2774851)

2867080569122160은 -방향으로 오차를 줄이는 방식으로 다시 계산된 값이다.

![Screenshot from 2021-03-24 10-54-26](https://user-images.githubusercontent.com/18409763/112242530-648b6100-8c8f-11eb-8021-41c1247058b6.png)


3월 24일 오전, 2개의 LGTM을 받아 머지시켰다.

---

[\<angle>](https://developer.mozilla.org/en-US/docs/Web/CSS/angle)은 각도를 나타내는 CSS 값 타입이다.


새로운 [CSS-Values-4](https://drafts.csswg.org/css-values/#numeric-types) 표준에 의하면 \<angle>의 최댓값은 표현가능한 범위에서 360값의 배수여야 한다. 

360의 배수이면서 특정한 값보다 작으면서 가장 가까운 값을 구하는 방법이 무엇일까?

바로 다음과 같은 식을 이용하면 된다.

$$result = target - target \ mod \  360$$

하지만 double의 최댓값에선 다음과 같은 문제가 발생한다. 

![Screenshot_from_2021-03-21_13-30-22](https://user-images.githubusercontent.com/18409763/111940095-44359800-8b11-11eb-9471-8ba0282e9f62.png)


이 결과는 우리가 예상한 동작과는 거리가 있어보인다. 실제로, `1.79769e+308 === 1.79769e+308 - 100` 은 `true` 를 내놓는다.

왜 이런 걸까?

컴퓨터 공학 학부, 혹은 컴퓨터를 처음 입문하게 되면 컴퓨터가 값을 표현하는 자료형의 범위를 배우게 된다.

그중에서 배정밀도 double은 8바이트로써, 범위는 다음과 같다.

±1.7 ×10^-307 이상 ± 3.4 × 10^308 이하

[IEEE 754](https://en.wikipedia.org/wiki/IEEE_754)에 따르면 배정밀도는 다음과 같은 비트열을 가지게 된다. 

위 값은 exponent를 포함한 아래 비트열의 모든 비트를 사용했을 때 나올 수 있는 최댓값이다.


![Untitled](https://user-images.githubusercontent.com/18409763/111940123-4f88c380-8b11-11eb-85ad-6d1e37a46068.png)


하지만 실제로 계산할 수 있는 범위는 훨씬 작아지는데, 그 이유는 부동소수점에서 exponent 값을 넘어가게 되면 2의 배수로 증가하기 때문이다. 즉, 일반적으로 우리가 기대하는 연산(사칙연산, 삼각함수 등)이 불가능하다.

[Double-precision floating-point format](https://en.wikipedia.org/wiki/Double-precision_floating-point_format) 의 **Precision limitations on integer values** 에 따르면, 정수에 대응될 수 있는 숫자의 표현 범위는 2^53 ~ -2^53인, 9007199254740992 ~ -9007199254740992이다.

이 아래부터는 chromium에 대한 이야기다.

---

chromium에서 \<angle>의 무한 값은 `2867080569122160` 로 정하게 되었는데 그 이유는 다음과 같다.

Chromium에서 "각"은 결국 **라디안** 이라는 단위로 계산이 된다. 이는 rotation matrix에서 삼각함수를 사용할 때 활용된다. 이와 반대로 CSS Math Function은 항상 **degree**로 반환한다. 즉, degree 값을 radian으로 변환시켜야 transform matrix로 사용할 수 있다는 이야기가 된다. 이 것은 [deg2rad function](https://source.chromium.org/chromium/chromium/src/+/master:third_party/blink/renderer/platform/wtf/math_extras.h) 함수를 통해 degree를 radian으로 변환하게 되는데 이 식은 다음과 같다.

$$rad = \frac{degree *\pi}{180}$$

여기서 문제는 저 최댓값인 9007199254740992에 원주율을 곱하게 되면 우리가 예상하지 못한 동작을 하게 된다는것 이다. 따라서 다음과 같은 식으로 PI를 곱했을 때 표현 가능한 범위를 넘어가지 않도록 해주었다.

$$base = \frac{9007199254740992}{\pi}$$

$$degree = base - base \ mod \ 360$$

여기서 sin함수를 dgree에 사용했을 때 0.01의 오차를 가지게 되었다. 하지만 이는 충분하지 않다고 생각하여 다음과 같은 스크립트로 0.00001의 오차를 가진 값을 찾아냈다.

```jsx
//To find nearest value using trigonometric functions

while((Math.abs(Math.sin(degree * Math.PI / 180))) > 0.00001 || 
       !(Math.sin(degree * Math.PI / 180) >= 0 && Math.cos(degree * Math.PI / 180) > 0 )) {
    degree -=1;
}
console.log(degree)
```

이렇게 해서 나온 결과가 `2867080569122160` 이다.

따라서 값(`-2867080569122160` ~ `2867080569122160`)을 \<angle>의 clamp값으로 선정하였다.