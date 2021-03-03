---
layout: post
title: Flux 아키텍처
date:   2021-03-03 05:02:20
categories: development
comments: true
languages:
- korean
tags:
- React
- Web
- Flux
---		

이번 글에서는 면접 질문으로 들어왔던 Redux 써봤냐 → 그럼 flux 구조를 아느냐 에 대한 답변을 내 개인적으로 시원하게 하지 못해 아쉬움에 내용을 정리해 보도록 한다.

Q: Flux 구조에 대해서 알고계신게 있나요?

"사실 Flux는 들어만 보았고, 정확하게 어떤 것을 의미하는 지는 기억하지 못합니다. 저는 이 구조가 글로벌 상태 관리를 하는 패턴이라고 알고있습니다. 이 구조를 활용한 Redux를 사용하여 어플리케이션을 개발했는데~".

이번 기회에 Flux구조에 대해 다시한번 공부해보도록 한다.

3줄 요약 부터 해보도록 한다.

1. FLUX는 MVC패턴과 같은 패턴의 한 일종이다. 
2. 단방향으로 데이터가 흐른다.
3. Redux와 같은 녀석들은 이러한 구조를 편하게 쓸 수 있게 해주는 것들이다.

사실 위 3줄 요약보다 더 간단한 이미지가 있다.

![Untitled](https://user-images.githubusercontent.com/18409763/109767232-93875780-7c3a-11eb-86f3-753e5c7a4674.png)


화살표는 데이터의 흐름을 의미한다.

이미지에서 볼 수 있듯이 단방향으로 흐른다.

그렇다면 만약 사용자가 인터렉션을 취해서 상태를 변경한다면 어떻게 될까?

![Untitled 1](https://user-images.githubusercontent.com/18409763/109767265-9f731980-7c3a-11eb-95fb-089ead36252c.png)


다시 dispatcher를 통해 데이터를 action을 이용해 보내게 된다. 

### Dispatcher

 Dispatcher는 Flux 아키텍처에서 모든 데이터의 흐름을 관리한다.  액션을 분배하고 store에 콜백을 등록하는 등 간단한 메커니즘으로 동작한다. 

Action Creator가 새로운 action이 있다고 dispatch를 호출하면 어플리케이션의 모든 store는 action을 등록한 callback으로 전달받는다.

아래는 dispatcher의 실제 구조이다. 

```tsx
dispatch(payload: TPayload): void {
    invariant(
      !this._isDispatching,
      'Dispatch.dispatch(...): Cannot dispatch in the middle of a dispatch.'
    );
    this._startDispatching(payload);
    try {
      for (var id in this._callbacks) {
        if (this._isPending[id]) {
          continue;
        }
        this._invokeCallback(id);
      }
    } finally {
      this._stopDispatching();
    }
  }
```

[https://github.com/facebook/flux/blob/5f6d5817a63e275c95b571ca2949379c4c1640b5/src/Dispatcher.js#L180](https://github.com/facebook/flux/blob/5f6d5817a63e275c95b571ca2949379c4c1640b5/src/Dispatcher.js#L180)

위 설명대로 모든 callback을 invoke한다. (_invokeCallback함수에서 payload를 전달해준다.)

### Store

스토어는 어플리케이션의 상태와 로직을 가지고 있다. Store라는 이름 답게 상태를 저장하고 있다고 생각해도 좋을 것 같다.

store는 개별적인 도메인에서 상태를 관리해주는데 이는 스토어별로 dispatcher token을 별도로 할당하기 때문이다.

이걸 조금더 풀어쓰기 위해 flux 공식 문서에 따르면 "페이스북의 되돌아보기 비디오 편집기"는 트렉의 플레이백 포지션 같은 정보를 TimeStore에 관리(트레킹) 하고 "이미지"는 ImageStore에서 관리하는 것 을 말할 수 있다.

### Action

 Dispatcher는 action을 호출해 데이터를 불러오고 store로 전달할 수 있게 해주는 메서드를 제공한다. 

변경할 데이터가 담겨진 객체라고 이해해도 찮을 것 같다. 

이런식으로 생겼다.

```tsx
{
      actionType: 'city-update',
      selectedCity: 'paris'
 }
```

### View와 Controller-View

 store로부터 이벤트를 받으면 데이터를 비교하여 `setState()`  또는 `forceUpdate()` 매서드를 호출하게 되어 화면이 갱신된다. 

컨트롤러 뷰는 자식에게도 데이터를 흘려보낸다고 한다.

[https://github.com/facebook/flux/blob/5f6d5817a63e275c95b571ca2949379c4c1640b5/src/container/FluxContainer.js#L187](https://github.com/facebook/flux/blob/5f6d5817a63e275c95b571ca2949379c4c1640b5/src/container/FluxContainer.js#L187) 

여기서 그 역할을 하는 것 같다.

---

## Redux?

Redux는 Reducer + Flux 라는 뜻을 가지고 

Flux에서 간소화 시키고 간단한 사용을 주제로 개발되었다고 한다.

Flux 개발자인 Jing Chen이나 Bill Fisher의 찬사를 받았다고 한다.

아래는 차이점이다.

![Untitled 2](https://user-images.githubusercontent.com/18409763/109767292-aa2dae80-7c3a-11eb-8b03-3fb8c41fc800.png)

![1_f3gS9znOZvX8HfCLg7T--Q](https://user-images.githubusercontent.com/18409763/109767214-8b2f1c80-7c3a-11eb-9b79-2819f00a1311.gif)

리덕스는 스토어가 하나이고, 디스페쳐가 없으며, immutable state(Reducer가 순수함수여서 copy 해서 replace 하는 방식으로 변경) 라고 한다.

 나중에 기회가 된다면 redux 내부 코드도 한번 훑어보고 싶다.

---

refs

[https://facebook.github.io/flux/docs/in-depth-overview](https://facebook.github.io/flux/docs/in-depth-overview)

[https://medium.com/dailyjs/when-do-i-know-im-ready-for-redux-f34da253c85f](https://medium.com/dailyjs/when-do-i-know-im-ready-for-redux-f34da253c85f)

[https://medium.com/@dakota.lillie/flux-vs-redux-a-comparison-bbd5000d5111](https://medium.com/@dakota.lillie/flux-vs-redux-a-comparison-bbd5000d5111)