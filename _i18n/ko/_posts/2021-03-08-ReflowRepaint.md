---
layout: post
title: Reflow, Repaint Chromium 입장에서 살펴보기 (왜 transform은 빠를까?)
date:   2021-03-08 00:00:00
categories: development
comments: true
languages:
- korean
tags:
- Web
- HTML
- CSS
- Optimization
---		
# Overview

Reflow와 Repaint에 대해서 면접 단골 질문이라고 해서 조금 깊이 살펴보도록 한다.  
최적화와 관련된 이야기며, Message Queue (event loop)에 대한 이해가 필요하다. 그 내용은 [여기서](https://devsdk.github.io/ko/development/2021/02/25/ChromiumEventLoop.html) 볼 수 있다. 요약하자면, 만약 js 태스크와 같은 작업이 message queue에서 선점되어 animation frame이 늦어지는 경우 사용자에게 애니메이션이 끊기는 등의 경험을 줄 수 있다. 이런 것을 피하고 최적화할 수 있는 방법에 대해 알아본다.
### Table of contents

1. Reflow, Repaint, Layout, Paint, Composite
2. CSS Animation
3. 왜 transform을 이용하면 빠를까?
4. tracing으로 알아보는 실제 layout, paint

# 1. Reflow, Repaint, Layout, Paint, Composite

이 글에서 Reflow와 Repaint는 Layout과 Paint와 대응된다. Reflow와 Repaint는 firefox의 "Gecko" 진영에서 주로 사용하고, layout과 paint는 safari의 webkit과 chromium의 blink 진영에서 사용한다. 혼동을 피하고자 layout과 paint로 설명하도록 한다.

### Layout은 무엇일까?

 웹브라우져에는 사실 DOM Tree 말고 렌더 스테이지에서 중요한 역할을 하는 트리가 하나 더 있다. 화면에 실제로 그리기 위해 박스모델과 좌표 계산이 끝난 상태인 Layout Tree라는 것을 관리한다. 이는 DOM Tree와 대응되지 않으며, display : none인 경우에는 아예 Layout Tree에 제외되기도 한다. 이러한 내용이 궁금하다면 [여기](https://docs.google.com/presentation/d/1boPxbgNrTU0ddsc144rcXayGA_WF53k96imRH8Mp34Y/edit#slide=id.ga884fe665f_64_528)를 살펴보면 좋을 것 같다. layout 단계 혹은 reflow는 **이 트리를 전체 혹은 일부를 새로 구성하는 것**을 의미한다. layout이 발생한다는 경우에 대해서는 [이곳에서](https://sites.google.com/site/getsnippet/javascript/dom/repaints-and-reflows-manipulating-the-dom-responsibly) 리스트업을 하지만 브라우져 레벨에서 **"항상" layout이 발생하는 것은 아니다.** 예로 CSS Animation을 들 수 있다.

### Paint는 무엇일까?

 위에서 만든 LayoutTree를 순회하며 Paint Command를 만들고 [SKIA](https://skia.org/) 레스터라이저한테 전달하는 단계이다.  이를  추상화하고 줄여서 설명하면 **Layout Tree를 화면에 그리는 단계**라고 이해해도 좋을 것 같다. 여기서 layout 트리에 대응되는 computed style에서 color와 같은 값을 가져와서 화면을 그리게 된다.
 이 단계 또한 매우 방대하며, 관심 있다면 [이 문서](https://chromium.googlesource.com/chromium/src/+/master/third_party/blink/renderer/core/paint/README.md#Current-compositing-algorithm-CompositeBeforePaint)를 보도록 하자.

### Composite?

Composite은 각각의 분리 가능한 레이어를 분리해서 처리한 뒤 합성하는 것이다. 거시적인 관점에서 **Composite는 Main Thread (Message Queue)에서 벗어나서 다른 Thread Flow를 가지고 화면을 업데이트** 할 수 있다. 즉 비동기적으로 실행된 후 기존 레이어에 합성된다. 주로 animation과 scroll 등등에서 활용되며, 다른 Thread Flow를 가지기 때문에 main thread에서 block이 일어나도 composite만 사용하는 애니메이션은 계속 재생될 수 있다.

![image](https://user-images.githubusercontent.com/18409763/110417527-1dbb3a00-80d9-11eb-9724-e26417c8324d.png)
*Composition example from [Life of Pixels](https://docs.google.com/presentation/d/1boPxbgNrTU0ddsc144rcXayGA_WF53k96imRH8Mp34Y/edit#slide=id.ga884fe665f_64_1213)*

# 2. CSS Animation

CSS Animation은 공짜가 아니며 브라우져의 리소스를 사용한다.

[https://csstriggers.com/](https://csstriggers.com/)

위 사이트는 CSS Animation이 렌더 스테이지에서 어떤 단계를 trigger 하는지 보여준다.

여기서 Layout > Paint > Composite 순으로 cost가 높으며 composite만 있다면 Message Queue와 무관하게 동작하므로 매우 좋은 애니메이션 타겟이 될 수 있다.

![Untitled](https://user-images.githubusercontent.com/18409763/110276915-8641e280-8017-11eb-8f9d-777e61cde490.png)

![Untitled 1](https://user-images.githubusercontent.com/18409763/110276931-8f32b400-8017-11eb-8b37-f3a5209dd077.png)

width의 cost는 Layout, Paint, Composite를 전부 사용한다. 따라서 꽤 높은 비용이라고 할 수 있다.

![Untitled 2](https://user-images.githubusercontent.com/18409763/110276946-98bc1c00-8017-11eb-9929-2508783b42b0.png)


background-color는 paint, composite를 사용한다. 

# 3. 왜 transform을 이용하면 빠를까?

![Untitled 4](https://user-images.githubusercontent.com/18409763/110276963-a2458400-8017-11eb-8c3e-029f7f5c0b3c.png)
![Untitled 3](https://user-images.githubusercontent.com/18409763/110276965-a376b100-8017-11eb-962b-e7945a3dd8c2.png)

우리는 같은 역할을 하는 두 가지의 코드를 만들 수 있다. 

```jsx
<style>
    .b { height: 50px; width: 50px; background-color: blue;}
</style>

<div class="b" style="transform: translateX(200px)"></div>
<div class="b" style="position:relative;left:200px"></div>
```
![Untitled 5](https://user-images.githubusercontent.com/18409763/110276977-ad001900-8017-11eb-9022-42350b5a8555.png)


위 코드는 완전히 화면에 동일한 결과를 내놓는다. 하지만 내부적으로 다르게 동작한다.

 컴퓨터는 그래픽을  matrix의 곱으로 표현한다. ([OpenGL examples](http://www.opengl-tutorial.org/beginners-tutorials/tutorial-3-matrices/)) 이는 OpenGL, DirectX 등에 반드시 사용되며 GPU는 이런 연산을 빠르게 하기 위해 설계되었다.

transform을 사용한 예시중 첫번째 div는 최종 composite에서 [transformation matrix](https://en.wikipedia.org/wiki/Transformation_matrix)를 통해 렌더링 되기 전 composite thread에서 GPU의 도움을 받아 계산된다.  아주 빠른 연산이 비동기적으로 일어나 매우 빠른 속도를 보여준다.  어떤 연산이 일어나는지는 [표준을](https://drafts.csswg.org/css-transforms/#mathematical-description) 참고하자. 심지어 Main Thread가 다른 태스크에 의해 block 되어도 재생된다.

left를 사용한 아래 예시는 layout→composite.assign->paint의 절차를 모두 밟게 된다. 즉 애니메이션으로 사용되기엔 꽤 비싼 cost를 가지고 있다는 소리다.
(Paint → Composite 는 현재 [Chromium의 주요 프로젝트중](https://bugs.chromium.org/p/chromium/issues/detail?id=471333) 하나이다. CAP (Composition After Paiting)이라고 불린다.)

![Peek 2021-03-09 16-40](https://user-images.githubusercontent.com/18409763/110435489-6c2b0180-80f6-11eb-9c35-82824d8ad351.gif)

여기서 즐거운 결론을 낼 수 있다. animation에서 만약 같은 결과를 내는 코드라면 **composite만 사용하는 애니메이션 (i.e.transform)**을 애용하자.

# 4. Tracing으로 알아보는 실제 layout, paint

 아래부터의 내용은 chromium/chrome의 동작 구조를 직접 살펴보며 위에서 이야기한 내용을 눈으로 봐볼 것이다.

아래는 width를 이용한 animation을 tracing 한 것이다.

![Screenshot_from_2021-03-08_11-45-14](https://user-images.githubusercontent.com/18409763/110277005-c0ab7f80-8017-11eb-9b93-6fa9b7769b5e.png)

 CrRendererMain에 바코드처럼 빼곡하게 있는 것들이 바로 layout→paint 그리고 composite를 트리거 하는 단계이다.

저 바코드의 줄 하나를 확대하면 다음과 같다.

![Screenshot_from_2021-03-08_13-45-51](https://user-images.githubusercontent.com/18409763/110277012-c608ca00-8017-11eb-999d-aa8f220241a2.png)

 트레이스가 기록된 저 상자는 c++ 구현과 1대1로 대응되며, 필요하다면 소스코드를 볼 수 있다. 이 내용을 보면 [LocalFrameView::UpdateStyleAndLayoutIfNeededRecursive()](https://source.chromium.org/chromium/chromium/src/+/master:third_party/blink/renderer/core/frame/local_frame_view.cc;l=3312;drc=3c992b98c58db034eb5af6bc51aac6fb1939d571)이 호출됨으로써 layout과 paint가 끊임없이 일어난다는 것을 알 수 있다.

 만약 DOM Tree의 깊이가 깊어진다면 그만큼의 recursion 호출이 발생한다.

그렇다면 반대로 transform을 사용한 경우는 어떤 트레이싱을 볼 수 있을까?

![Untitled 6](https://user-images.githubusercontent.com/18409763/110277028-cdc86e80-8017-11eb-87dc-550b7e53f85a.png)

 앞에 빼곡하게 있는 것은 마우스 때문에 발생한 animation이고 실제로 trigger 돼서 화면에 보인 것은 갑자기 빈 공간이 생기는 부분부터 이다. 여기서 compositor는 전달받은 역할을 **비동기적**으로 실행하는 것을 볼 수 있다. 이런 이유 때문에 composite만 사용하는 애니메이션은 alert와 같이 main thread가 block 된 상황에서도 정상적으로 렌더 수행이 진행된다.

오타/질문/틀린 내용이 있다면 언제든지 피드백 바란다. :)