---
layout: post
title: Chromium Composition과 Layer
date:   2021-03-29 00:00:11
categories: development
comments: true
languages:
- korean
tags:
- Chromium
- Chrome
- Blink
- Renderer
---	

웹 브라우져의 화면은 다양한 스테이지를 거쳐 화면에 나오게 된다.

다음은 chromium의 렌더링 과정을 도식화한 것이다.

![Untitled](https://user-images.githubusercontent.com/18409763/112830711-dd464f00-90cd-11eb-8750-3ec8b70fa093.png)


이번 글에서 다루고자 하는 내용은 빨간색으로 네모 친 Composition(합성)이다.

저번에 [Reflow와 Repaint](https://devsdk.github.io/ko/development/2021/03/08/ReflowRepaint.html)라는 내용을 다루면서 짧게 이야기를 한 적 있다.

이번 글에는 조금 더 구체적으로 이야기해 보고자 한다.

### Compositing?

한국어로 합성이라고 한다. 

실제로 브라우져는 렌더링을 최대한 최적화 하기 위한 많은 노력을 하고 있는데 여기에 Composition이 포함된다.

설명하기 이전에 용어를 조금 정리한다.

화면에 보이는 공간을 [Viewport](https://en.wikipedia.org/wiki/Viewport)라고 부른다. 

그리고 특정한 정보를 화면의 픽셀로 만드는 과정을 [레스터라이즈](https://en.wikipedia.org/wiki/Rasterisation) 라고 한다.

만약 Compositing이 없었다면 렌더링은 어땠을까? 

아래는 composite 없이 single layer로 렌더링이 되었을 때 벌어질 수 있는 것을 그림으로 나타낸 것이다.

![ezgif-6-f0af620c7a69](https://user-images.githubusercontent.com/18409763/112830531-a07a5800-90cd-11eb-8a8c-3de432ac0a8b.gif)

이 이미지는 Chromium의 가장 첫 번째 버전에서 동작하는 방식이었다.

스크롤과 같은 행위로 뷰포트를 넘어가는 경우 빈 공간을 다시 레스터라이즈 하는 과정이 있었다.

여기서 문제는 다른 요소가 변경(위치, 색상 등등)된다면 그 해당하는 공간을 다시 계산해야 한다는 점이었다. 

현대의 브라우져는 이러한 문제를 세련되게 해결하고 있다.

다음 그림은 layered composition을 설명하는 그림이다.

![ezgif-6-d9bdba71caac](https://user-images.githubusercontent.com/18409763/112830733-e7684d80-90cd-11eb-8bfb-02cef19c7124.gif)


Composition은 분리 가능한 레이어를 분리하고 미리 레스터라이즈를 한 뒤, 그 레이어를 움직이거나 Viewport를 움직이는 방식이다.

특정한 레이어의 레스터가 변경되고, 위치가 변경된다고 해서 다른 레이어의 요소에 영향을 끼치진 않는다. 

실제로 분리된 레이어를 살펴보자.

다음은 토이프로젝트로 만들었던 [DFD](https://github.com/DevSDK/DFD)의 layer이다.

React-Virtualized에 의하여 실시간으로 리스트가 갱신되는 것을 볼 수 있다.

![Peek_2021-03-29_14-48](https://user-images.githubusercontent.com/18409763/112830772-f51dd300-90cd-11eb-9f3c-f4a749a82ae9.gif)

다음은 github의 layer이다.

스크롤에 의해 floating이 되는 부분이 새로운 레이어로 만들어짐을 잘 살펴보자.

![Peek_2021-03-29_14-53](https://user-images.githubusercontent.com/18409763/112830808-01099500-90ce-11eb-9bff-a802957b2ff5.gif)

이처럼 실제로 composition은 웹에서 최적화를 담당하는 큰 축중 하나로 사용되고 있다.

### How?

그렇다면 Layer은 어떻게 분리가 될까? 

![Untitled 1](https://user-images.githubusercontent.com/18409763/112830907-27c7cb80-90ce-11eb-9c56-b98824525a47.png)

렌더러는 DOMTree에서 만들어진 LayoutTree를 이용하여 Compositing Trigger를 가진 녀석들을 layer로 분리시킬 후보로 만든다. 여기서 말하는 트리거는 다양한 이유가 될 수 있는데 대표적으로 transform 요소가 될 수 있다.

![Untitled 2](https://user-images.githubusercontent.com/18409763/112830912-29918f00-90ce-11eb-94f0-337026cb0326.png)

기존에는 LayerTree를 사용했던 것 같은데, v2부터는 Layer List를 사용하는 것 같다.

또한 Scrollable Area에 대해서는 아래와 같이 layer를 나뉘게 된다.

![Untitled 3](https://user-images.githubusercontent.com/18409763/112831024-4e860200-90ce-11eb-86f6-7a46e2de1f99.png)


이렇게 만들어진 레이어들은 Compositing Assignment라는 단계에서 그래픽 레이어로 변환된다.

![Untitled 4](https://user-images.githubusercontent.com/18409763/112831051-59409700-90ce-11eb-9746-d18617675748.png)


각각에 레이어에 대해 다양한 파라미터를 줄 수 있는데 이것을 **property tree**라고 부른다.

![Untitled 5](https://user-images.githubusercontent.com/18409763/112831071-5f367800-90ce-11eb-9219-736535770b5a.png)
![Untitled 6](https://user-images.githubusercontent.com/18409763/112831085-63629580-90ce-11eb-996c-26286c59d5fd.png)
현재까지의 Chromium의 구현체 (Composite After Paint 이전)에는 이 프로퍼티 트리를 레이어가 가지고 있게 된다. 아마 CAP에서는 이를 분리시킬것 이라고 한다.

이렇게 만들어진 Layer과 Property Tree는 메인쓰래드에서 별도의 compositor thread로 넘기게 된다.

![Untitled 7](https://user-images.githubusercontent.com/18409763/112831088-6493c280-90ce-11eb-88d0-04ff9ac4e242.png)
![Untitled 8](https://user-images.githubusercontent.com/18409763/112831091-652c5900-90ce-11eb-8c0a-6a0b9093d1e7.png)

그 후 draw콜에 의하여 레이어가 화면에 그려지도록 렌더 커멘드를 생성하며 다음 스테이지로 넘기게 된다.

---

refs

[https://developers.google.com/web/updates/2018/09/inside-browser-part3#what_is_compositing](https://developers.google.com/web/updates/2018/09/inside-browser-part3#what_is_compositing)

[http://bit.ly/lifeofapixel](http://bit.ly/lifeofapixel)

[https://source.chromium.org/chromium/chromium/src/+/master:third_party/blink/](https://source.chromium.org/chromium/chromium/src/+/master:third_party/blink/)