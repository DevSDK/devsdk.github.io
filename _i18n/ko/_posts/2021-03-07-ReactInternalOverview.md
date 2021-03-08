---
layout: post
title: React 파헤치기, 리액트가 동작하는 방법 (overview)
date:   2021-03-07 00:00:00
categories: development
comments: true
languages:
- korean
tags:
- React
- Web
- React-DOM
---		
# Motivation

Chromium에서 활동하면서 웹브라우져가 어떻게 동작하는지는 어느 정도 (완벽할 순 없다고 생각한다.. 너무 거대하다.)알고 있다.

그리고 리액트를 사용하는 방법을 알고 있다.

그러나 React-DOM과 내부 사항들에 대해서는 너무 추상적으로 알고있거나 모른다고 생각한다.

그래서 리액트와 브라우져 사이의 블랙박스가 너무 궁금하여 몇몇 가지의 문서와 react 소스코드를 뒤졌던 결과 어느정도 오버뷰가 나올 것 같아서 블로그에 정리하도록 한다.

하지만 아직 완전히 모든 소스코드를 본 것은 아니며, 생략되거나, 틀릴 수도 있는 내용이다.

언제든지 피드백을 받는다면 반영하도록 하겠다.

![Untitled (2)](https://user-images.githubusercontent.com/18409763/110232600-03128500-7f62-11eb-8f38-c3e5015e0303.png)


이 글을 쓰기 시작한 큰 이유다.

 중간에 블랙박스가 너무 많아 실제로 어떻게 동작하는지 그리고 내가 더 생각해 볼 수 있는 다른 방향은 없는지 알기가 어려웠다. 덧붙이자면 말 그대로 **마법상자** 가 있어서 이를 화면에 그려주고 상태를 변경시키는 작업을 하는 느낌을 받았다.

 지금부터 그 마법상자를 열어보도록 한다. 

# Overview

![Untitled (3)](https://user-images.githubusercontent.com/18409763/110232607-09a0fc80-7f62-11eb-9780-6bd6e032638c.png)

글 내용이 뒤죽박죽이라, 아래의 내용을 바탕으로 위의 이미지를 정리하면 다음과 같다.

콜백에 의해 fiber 스케쥴러가 업데이트되고, 그 스케쥴러는 fiber들의 테스크를 실행하여 산출물인 업데이트 트리(WorkInProgress or Finished)를 Commit을 통해 dom에 반영한다.

# Detail

 React는 다음과 같은 JSX 문법을 통해 "선언적" 인 구현을 권장한다. ([리엑트 공식 문서](https://reactjs.org/docs/jsx-in-depth.html))

리액트를 처음 썼을때 가장 놀랐던 부분이기도 하다. 

```jsx
<MyButton color="blue" shadowSize={2}>
  Click Me
</MyButton>
```

공식문서에서도 설명하듯이, 이는 컴파일러에 의해 (babel-loader?) 다음과 같이 코드로 변경된다.

```jsx
React.createElement(
  MyButton,
  {color: 'blue', shadowSize: 2},
  'Click Me'
)
```

이 함수를 거치면서 아래의 계층을 가진 object 형식으로 반환이 된다.

DOM과 유사하게 children이 있고 여러 가지 정보들을 담고 있다.

(위 소스코드와 아래의 결과와는 다르다. 위는 공식문서에서 가져왔다.) 

![Untitled (4)](https://user-images.githubusercontent.com/18409763/110232637-3d7c2200-7f62-11eb-930c-b90f62771320.png)

이제 우리는 위 내용을 ReactDOM.render를 통해 react-dom에 전달한다. react-dom은 위 정보를 fiber 라는 형태로 관리한다. 

 Fiber는 react의 element는 1대1로 대응되면서 여러 내부 정보를 가지고 있는 구조이며 react의 작업의 단위가 되기도 하고, 자체적인 스택프레임을 가지는 일의 주체라고 한다.

 reconciliation 작업에 사용된다. (fiber는 [react-reconciler](https://github.com/facebook/react/tree/master/packages/react-reconciler/src) 패키지에서 관리한다.) 내부적인 reconciliation 알고리즘은 O(n)의 휴리스틱 한 알고리즘이라고 한다. 공식문서에서는 개발자가 key를 줌으로써 알고리즘에 힌트를 줄 수 있다는 중요한 내용이 담겨있다. 

그렇다면 fiber는 어떤 역할을 할까?

너무 [필드가 많아서](https://github.com/facebook/react/blob/7df65725ba7826508e0f3c0f1c6f088efdbecfca/packages/react-reconciler/src/ReactFiber.new.js#L111) 봤던 article의 내용 중 일부를 빌리자면 이렇게 생겼다.  

```jsx
{
    stateNode: new App,
    type: App,
    alternate: null,
    chiled:null,
    key: null,
    updateQueue: null,
    memoizedState: {},
    pendingProps: {},
    memoizedProps: {},
    tag: 0,
    effectTag: 0,
    nextEffect: null
     ...
}
```

 Tree 형태로 내용을 기반으로 순회하면서 WorkInProgress 트리를 만들게 된다. 그리고 WorkInProgress는 이후 화면으로 반영될 트리를 의미한다. 여기서 자주 보던 녀석들이 있는데 React.memo에 의해 property를 기록할 때 실제로 반영되는 필드인 memoizedProps와, 공식문서에서도 설명하던 key 필드이다. 이 필드는 reconciliation 작업에서 휴리스틱한 탐색에 주요 factor로 사용된다.

 또한, 자체적인 스택프레임을 가지고 있다는 부분이 정말 재밌는데, [이벤트루프의 동작 방식](https://devsdk.github.io/ko/development/2021/02/25/ChromiumEventLoop.html) 에 따르면 js execution이 길어지면 다음 태스크가 계속 기다려야 하므로 사용자경험이 안 좋아(애니메이션이 끊긴다거나, 터치가 씹힌다거나 등) 질 수 있는 것을 방지하기 위해 도입된 방식이다.

 fiber한테는 자체적인 실행 스택(work queue로 관리되는 듯해 보인다)을 가지고 자체적인 priority 기반 scheduler를 이용하여 태스크를 쪼개서 관리하면서 Message Queue가 다른 이벤트를 처리할 수 있도록 하여 Message Queue가 다른 task를 실행할 수 있도록 해주는 것 같다. 여기서 스케쥴러는 requestIdleCallback (requestAnimationframe?) API에 의해 호출된다.

 이제 react-dom의 마지막 산출 단계에서는 render 페이즈와 commit 페이즈로 나뉘게 된다.

 렌더페이즈는 위에서 서술했듯이 current 트리에서 WorkInPregress를 생성하는 (변경사항들을 찾아서 렌더링할 재료를 만드는) 단계라면 commit 페이즈는 말 그대로 화면에 그리도록 제출하는 단계이다. 여기서 didComponentMount 와 같은 lifecycle 함수들이 호출된다. (렌더 페이즈에서 호출되든 lifecycle 함수들은 UNSAFE_ 태그를 달고 있다고 한다.) 


실제로 react 소스코드에서 [commitUpdate](https://github.com/facebook/react/blob/c7b4497988e81606f1c7686434f55a49342c9efc/packages/react-reconciler/src/ReactFiberCommitWork.new.js#L1350), [commitPlacement](https://github.com/facebook/react/blob/c7b4497988e81606f1c7686434f55a49342c9efc/packages/react-dom/src/client/ReactDOMHostConfig.js#L451) 등등을 통해 dom에 반영하는 것을 찾아볼 수 있다. 내부적으론 [insertBefore](https://developer.mozilla.org/en-US/docs/Web/API/Node/insertBefore) 와 같은 함수를 호출하는 것으로 보인다.

위 내용은 글 초반에 말했듯이, 소스코드레벨에서 완전한 이해를 바탕으로 쓴 글이 아니다.

몇몇 가지의 글을 보고, 소스를 뒤적이다가 오버뷰를 만들면 좋을 것 같다는 생각에 작성했다.

---

refs

[https://indepth.dev/posts/1008/inside-fiber-in-depth-overview-of-the-new-reconciliation-algorithm-in-react](https://indepth.dev/posts/1008/inside-fiber-in-depth-overview-of-the-new-reconciliation-algorithm-in-react)

[https://github.com/acdlite/react-fiber-architecture](https://github.com/acdlite/react-fiber-architecture)

[http://bit.ly/lifeofapixel](http://bit.ly/lifeofapixel)