---
layout: post
title: Chromium, Event Loop는 싱글 스레드
date:   2021-02-24 20:02:20		
categories: development
comments: true
languages:
- korean
tags:
- Chromium
- Javascript
- Web Sepc
---		

이곳저곳 코딩테스트를 마치고,

면접준비를 하면서 Javascript의 Event Loop에 대하여 설명하세요 라는 질문이 자주 나온다는 사실을 알았다.

내가 기억하는 이벤트 루프는 싱글스레드라서  태스크들을 순서대로 처리한다는 것이었다.

자바스크립트를 자주 사용했고, 분명 언제 본 내용일 텐데 까먹어서 표준 문서와 브라우져 코드를 좀 보았다.

검색을 하니까 알기 쉽게 잘 나와 있는 글을 발견했다.

[https://meetup.toast.com/posts/89](https://meetup.toast.com/posts/89)

이 글을 보고,  의문점이 좀 생겨 알아보기로 했다.

### 2. 이벤트루프의 정의

[WHATWG의 HTML 표준](https://html.spec.whatwg.org/multipage/webappapis.html#event-loops)에 따르면, 

`
To coordinate events, user interaction, scripts, rendering, networking, and so forth, user agents must use event loops
`

"이벤트, 유저 인터렉션, 스크립트, 렌더링, 네트워킹 등등과 같은 것들은 이벤트 루프를 **반드시** 사용해야 합니다."

즉 무엇인가 "일" (화면을 그린다거나, HTML을 파싱한다거나)을 하는 모든 것들은 이벤트 루프를 사용해야 한다고 명시되어 있다. 실제로 표준에서는 구체적으로 어떤 일들이 이벤트 루프를 사용할지 적어두었다.

내가 이해한 바로는, 웹브라우저가 OS 라고 한다면, Event Loop라는 CPU에서 처리되어야 한다는 느낌을 받았다.

하지만, 위 구조라면 통신과 같은 작업이 동기적으로 실행되고 이는 HTTP 통신이 있다면 다른 태스크를 실행하지 못한다는 이야기가 된다. 우리가 웹 환경을 이용하면서 통신이 있을 때마다 클릭이 안 된다거나 그런 일은 있지 않았다. 어떻게 된 일일까?

### 3. 이벤트루프

MDN의 [Concurrency model and the event loop](https://developer.mozilla.org/en-US/docs/Web/JavaScript/EventLoop) 에 따르면, 현대 자바스크립트는 다음 그림으로 설명할 수 있다.

![Untitled](https://user-images.githubusercontent.com/18409763/109103285-f32ec000-776d-11eb-8db8-58de71874a3c.png)


위 이미지에서 중요하게 봐야 할 것은 **단일스택** 이라는 점이다.

또한 중요하게 다루고 있는 개념이 있는데 **"Run-to-completion"**이다.

메시지가 처리되고 난 뒤 다음 메시지를 처리하는 것이다. (만약 무한루프와 같이 처리가 끝나지 않는다면 다음 이벤트는 영원히 처리되지 않게 된다. 물론 브라우져에서 이에 대한 alert을 제공한다.) 

위에서 말한 것과 같이 Event Loop 혹은 Message Queue에는 다양한 작업이 들어간다.

이 다양한 작업 중 하나인 Javascript Execution의 끝은 무엇일까?

조금 단순히 말하자면, 스택이 비었다→ JS작업이 완료되었다고 볼 수 있다.

그렇다면 여러 콜백 함수, 비동기적인 실행은 어떻게 처리하는 것일까?

### 4. 이벤트루프의 내부 구조

이벤트루프에 등록된 일들은 태스크라는 단위로 변경되어 브라우져에서 처리된다. 

(사실 크롬에서는 EventLoop 라는 개념이 스팩과 조금 다르게 구현되어 있다.)

- third_party/blink/renderer/platform/scheduler/public/event_loop.h

    ```
    // The specification says an event loop has (non-micro) task queues. However,
    // we process regular tasks in a different granularity; in our implementation,
    // a frame has task queues. This is an intentional violation of the
    // specification.
    ```

문서와 코드를 좀 보니까, 의외로 금방 찾았는데 MessagePump라는 곳에 있었다.

Chromium에서의 스케줄링은 다양한 방식으로 진행한다. 그리고 그 스케쥴링의 결과가 아래 함수에서 실행된다.

아래 코드에서 Task는 이벤트랑은 조금 다른, 브라우져에서 관리하는 실행 컨텍스트이다.

DoWork 내에서 우리가 알고있는 이벤트 루프의 행위가 벌어진다.

[[여기]](https://source.chromium.org/chromium/chromium/src/+/master:base/message_loop/message_pump_default.cc;l=31;drc=9d1a1d6154cae517f76de279682185c8abc30868) 서 더 자세히 볼 수 있다.

![Untitled 1](https://user-images.githubusercontent.com/18409763/109103312-fd50be80-776d-11eb-894f-6a7a0da624bc.png)


연관된 코드가 너무 많아 다 설명하기 어려울 것 같지만 위 코드면 어느 정도 정리가 될 것 같다.

위 코드를 보면

무한루프 속에 태스크가 순차적으로 실행되고 있음을 알 수 있다. 

태스크는 *아마도* 스케줄러에 의해 계속 변할 것이다.

(Event Loop의 경우 microtask를 우선 실행하고, 원래 태스크를 실행하는 그런 일련의 작업)

메인 Task가 아니거나, 비동기적으로 실행될 수 있는 태스크의 경우 다른 곳에서 실행된다.

setTimeout, xmlhttprequest와 같은 것은 내부 API를 사용하며, JS에서는 Non-Blocking으로 실행된다.

이들은 메시지 큐를 콜백 혹은 이벤트를 등록하는 데 사용한다. 만약 async 태스크가 완료되었다면 아까 등록한 이벤트나 콜백을 이벤트루프에 던져서 실행하는 형식이다.

그렇다면 그때 또 다른 실행 context가 생길 것(스택이 쌓이고 등등..)이고, 그 태스크가 끝나면 다음 이벤트를 처리할 것이다.

따라서 이벤트루프, 자바스크립트의 동작은 **싱글스레드** 지만, **내부적인 동작이나, API(DOM API 등) 들은 다른 Thread를 활용할 수도 있다**. 하지만 이러한 요청과 결과는 이벤트 루프에 의해 순차적으로 처리된다.

---

부족한 내용이나, 틀린 내용이 있으면 언제든지 댓글을 ...