---
layout: post
title: Chromium 새로 개발되는 DOM API Seamless Transitions
date:   2021-03-11 00:00:02
categories: development
comments: true
languages:
- korean
tags:
- Chromium
- Chrome
- CSS
---	

오랜만에 patch들을 pull 받고 빌드하는 시간 동안 Chromium에서 SPA(Single Page App)를 위한 API가 어떤 것들이 있을까 라는 생각으로 feature들을 살펴보던 도중 흥미로운 기능이 현재 막 개발되고 있어서 글을 쓴다. 

2021.03.11 기준으로 아직 한창 개발되고 있는 feature이다. Android Webview와 깊은 연관이 있는 만큼 나중에 완성되면 Google IO 같은 데서 한번 말하지 않을까 라는 생각이 든다. (아닐 수도 있다. ㅎㅎ..)

아직은 비표준인 것 같다. 아마 표준이 되지 않을까 생각된다. [WICS Proposal](https://github.com/WICG/proposals/issues/12)

[runtime flag](https://source.chromium.org/chromium/chromium/src/+/master:third_party/blink/renderer/platform/runtime_enabled_features.json5) 에 따르면 프로토타입은 나온것 같으니 한번 사용해보도록 한다.

![Untitled](https://user-images.githubusercontent.com/18409763/110785255-1436fb00-82ae-11eb-8fe2-5cdad35393b8.png)


# TL;TR

```jsx
function changeBodyBackground() {
  document.body.style = "background: blue";
}

function handleTransition() {
  document.documentTransition.prepare({
    rootTransition: "reveal-left",
    duration: 300
  }).then(() => {
    changeBodyBackground();
    document.documentTransition.start().then(() => console.log("transition finished"));
  });
}
```
트렌지션을 시도하기 전 그 화면을 texure로 렌더링해놓는다. 이 작업을 prepare라고 한다. 이 작업은 비동기적으로 실행되며 GPU 자원을 사용할 수 있다. 그런 뒤 Transition을 하면 렌더링해놓은 텍스쳐 뒤로/앞으로 DOM을 렌더링한다. 그런 뒤 요청한 방식대로 그 이미지를 제거한다. (like `reveal-right`)

문서의 motivation쪽을 보니 transition에 부족한점이 많아서 SPA를 혹은 MPA를 위해 시작했다고 한다.

# Example

개발하고 계신 분의 [example](https://github.com/vmpstr/shared-element-transitions/blob/main/sample-code/page_transition_spa.html)을 실행해본다. 실행조건은 pull 받은 시점의 [HEAD](https://chromium.googlesource.com/chromium/src.git/+/d6485e20161bf3590e295575e320ef7feca7e665)에서 빌드한 content_shell이다. 실행 커멘드는 `./content_shell --enable-features=DocumentTransition test.html` 이다. 

아무래도 Under Construction이라서 직접 실행해 보니 빌드 환경이 동일하지 않은 것 인지 크레시가 난다.

![Peek 2021-03-11 21-03](https://user-images.githubusercontent.com/18409763/110784763-6deaf580-82ad-11eb-9b92-17c0ef91beaf.gif)

explode와 implode는 그래도 잘 동작한다.

![Peek 2021-03-11 21-02](https://user-images.githubusercontent.com/18409763/110785324-2f096f80-82ae-11eb-8d00-760efae46532.gif)

이걸 만들고 계신 분이 데모로 올리셨던 영상을 따왔다.

![Peek 2021-03-11 21-23](https://user-images.githubusercontent.com/18409763/110786952-1dc16280-82b0-11eb-96ac-b28a7f7aa14f.gif)


디테일은 아래 문서 및 모노레일에서 볼 수 있다. 다시 한 번 말하지만, 아직 개발이 진행 중인 기능이다.


---

[https://crbug.com/1150461](https://crbug.com/1150461)

[https://github.com/vmpstr/shared-element-transitions](https://github.com/vmpstr/shared-element-transitions)

[https://docs.google.com/document/d/1UmAL_w5oeoFxrMWiw75ScJDQqYd_a20bOEWfbKhhPi8](https://docs.google.com/document/d/1UmAL_w5oeoFxrMWiw75ScJDQqYd_a20bOEWfbKhhPi8)