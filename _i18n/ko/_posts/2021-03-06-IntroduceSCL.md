---
layout: post
title: SCL Notion Checklist generator 개발
date:   2021-03-06 00:00:00
categories: development
comments: true
languages:
- korean
tags:
- Python
- Notion
- CLI
- Productivity
---		

아침 일찍 일어나서 취업준비를 위해 Chromium 커밋 리스트를 다시한번 훑어보는데 아뿔싸... 머지한 커밋중에 Commit Message와 코드가 다른 것을 보았다.

아래는 커밋 메시지 중 일부분.

![Untitled](https://user-images.githubusercontent.com/18409763/110193524-b488bc00-7e77-11eb-82eb-2b22114266cd.png)

아래는 실제 코드

![Untitled 1](https://user-images.githubusercontent.com/18409763/110193525-b5b9e900-7e77-11eb-90f9-be68a9a97b18.png)

아무래도 패치셋이 진행되면서 이름을 바꾸게 되었는데, CR+2받고 그냥 머지시킨 것 같다.

앞으로도 이런 실수를 안 하리라는 보장이 없기 때문에 scl이라는 간단한 프로젝트를 진행했다. 

아이디어는 다음과 같았다. "Commit Checklist를 패치별로 notion에 저장하면 편하지 않을까?"

notion은 api를 아직 정식으로 제공하지 않는다.

Private test 중이라고 하는데, 언제 열릴지 모르기 때문에 그걸 기다리기는 건 어려울 것 같다는 결론을 냈다.

처음에는 golang으로 짜인 라이브러리가 보이길래, go언어로 짜다가 block(노션의 컨텐츠)를 생성하는 것이 없어 다른 방법을 찾아보았다. 그렇게 API를 따서 python 라이브러리로 만든 notion-py을 발견했는데, notion 대부분의 기능을 사용할 수 있어서 python으로 갈아타기로 했다.

개발환경이 워낙 CLI와 가깝다 보니 CLI 기반으로 작성하였다.

레포지토리 [https://github.com/DevSDK/scl](https://github.com/DevSDK/scl)