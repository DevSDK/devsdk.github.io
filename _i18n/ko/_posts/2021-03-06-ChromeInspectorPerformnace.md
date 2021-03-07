---
layout: post
title: Chrome Inspector로 화면이 왜 느린지 찾아보기
date:   2021-03-06 00:00:01
categories: development
comments: true
languages:
- korean
tags:
- Chrome
- Web
- Javascript
- Optimization
- Debugging
---		

DFD를 구현하고 항상 들던 의문이 있었다.

화면을 구성하고 어느 순간부터 main 화면에서 로딩이 늦는것 

다루는 데이터가 그렇게 많은 편이 아닌데도 chart나 render 부분이 느린 것 같다는 생각이 종종 들었다. 물론 사용하는 데 전혀 지장은 없지만 UX 적으로 조금 개선할 방향을 찾아보고 싶었다.

가장 먼저 해본 것은, React Profiler를 사용해 확인하는 것이었다.

![Screenshot_from_2021-03-06_14-49-03](https://user-images.githubusercontent.com/18409763/110197436-fcffa400-7e8e-11eb-9df0-f3b2367aadae.png)


하지만 프로파일러에서는 계속 LOLGameElement 가 느린 것 같아!! 라고 이야기하고 있었다.

사실 살펴보면 시간 단위가 문제가 될 만큼 느리지 않았다. 즉 다른 곳이 느리거나, 놓치고 있는 게 있다는 것일 것이라는 가설을 세우게 되었다. 가장 느린 구간이 70ms라니, 이는 화면에 보이는 것보다 느린 것이 아니다.

또한 얻는 정보가 한정되어있다는 생각이 많이 들었다. 
(이는 내 react profiler 사용이 서툴러서 그런 것 일수도 있다.)

다른 방법을 취해보기로 했다. 

chrome://tracing에 들어가서 전체 렌더 시간에 일어나는 일들을 Web Developer Mode로 트레이싱 하였다. 

웹 개발자 모드로 한 이유는 그 정보로도 충분할 가능성이 높기 때문이다. 만약 필요해서 더 깊이 들어가야 한다면 Chromium flag를 enable 한 뒤 빌드하여 전체모드 트레이싱 하면 skia 렌더 커멘드 (네모 그리기가 매우 많다.) 단위까지 조사할 수 있다

트레이싱 도구를 사용한 이유는 다음과 같다.

1. 어떤 **렌더스테이지** 에서 시간을 쓰고 있는지 (ex, composition, layout, javascript execution, style compute recursion ... )
2. 디버깅에는 가능성을 최대한 열어두고 소거하는 것을 좋아한다.
3. 단계적인 접근 방법
4. 만약 필요하면 C++ 네이티브 코드를 바로 볼 수 있게 제공받는다.

![Screenshot_from_2021-03-06_14-43-40](https://user-images.githubusercontent.com/18409763/110197458-07ba3900-7e8f-11eb-9760-ff918d830abe.png)


일단 한눈에 들어온 정보는 v8이 가져가는 시간이 정말 많다는 점이었다. 

이 말은  javascript execution 쪽에서 느려짐을 의미한다. 여기서 다른 렌더 스테이지에서 느려지지 않는 것을 확인할 수 있었다.

이제 javascript execution을 추적하기 위해 insepcator를 이용하여 Performance 체크를 해보기로 했다.

![Screenshot_from_2021-03-06_15-03-22](https://user-images.githubusercontent.com/18409763/110197472-11dc3780-7e8f-11eb-8421-e4f1ec7361df.png)


가장 느려지는 구간은 3가지 정도인 것 같고, 공통점을 찾아낼 수 있었다.

![Untitled](https://user-images.githubusercontent.com/18409763/110197480-202a5380-7e8f-11eb-9e22-f0b6ce9f7e02.png)


apexchart 쪽에서 이러한 이벤트들이 모이고 모여 엄청 긴 시간을 가져가게 된 것이다.

여기서 잠정적인 결론을 내릴 수 있었다.

**Apexchart를 제거하거나 optimize 하면 이 느려지는 것이 해결 될 것**

최적화를 위해 관련 정보를 찾아보고 문서를 봐봤지만, Apexchart의 고질적인 문제인 것 같다는 생각이 든다.

일단 꽤 자주 퍼포먼스이야기가 (i.e. [github issue](https://github.com/apexcharts/vue-apexcharts/issues/208)) 보였다.

또한 내가 apexchart를 잘못 사용한 것인가? 라는 의문을 가지고 공식 홈페이지의 live demo에 가서 퍼포먼스 체크를 진행했다.

![Untitled 1](https://user-images.githubusercontent.com/18409763/110197498-39330480-7e8f-11eb-9547-62cb0c3a33f1.png)


공식 홈페이지의 Demo에서 데이터가 그리 많지 않음에도 꽤 많은 시간을 apexchart가 가져간다. 

아마도 고질적인 문제가 아닐까 조심스럽게 추측하면서, apexchart를 대체할 방법을 생각해 보면 좋을 것 같다는 생각이 들었다.