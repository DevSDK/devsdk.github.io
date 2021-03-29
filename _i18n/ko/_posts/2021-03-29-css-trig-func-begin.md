---
layout: post
title: \[CSS-Values-4] 삼각함수 구현 준비 
date:   2021-03-29 00:00:01
categories: development
comments: true
languages:
- korean
tags:
- Chromium
- Chrome
- CSS
- Feature
- css-values-4
---	

Chromium에 CSS에 대하여 Infinity 와 NaN을 구현하는 프로젝트가 거의 끝나가고 있다. 몇 가지의 이슈를 해결하면 아마 ship 할 수 있을 것 같다. 

이 기능을 구현하며 스팩을 자주 보게 되었는데, 익숙해 진 것도 있고, 눈에 띄는 기능이 보여서 다음 구현 목표를 css-values-4 스팩에서 찾게 되었다.

새로운 w3c/csswg의 표준인 CSS-values-4를 보면, [삼각함수에 대한 내용](https://drafts.csswg.org/css-values/#trig-funcs)이 담겨있다.

![Untitled](https://user-images.githubusercontent.com/18409763/112796569-203ffc80-90a5-11eb-90b0-911861731219.png)


더 빠르고, 안정적으로 CSS에서 삼각함수를 사용할 수 있게 될 것이라고 기대하고 있다.

아마도, hue 컬러 공간 및 삼각함수 관련된 스타일이 필요한 부분에서 유용하게 쓰일 수 있을 것 이라고 생각한다.

첫번째로 type=feature로 크로미움 이슈 모노레일 [crbug.com](http://crbug.com) 에 올려두었다. 

![Untitled 1](https://user-images.githubusercontent.com/18409763/112796587-26ce7400-90a5-11eb-982e-6c34cbf9c7e1.png)


아마 이 기능도 무한과 NaN 기능을 구현할 때와 마찬가지로 Intent to Prototype과 Design Docs, Chromium Platform Status 등에 등록이 필요할 것 같다.

구글 크롬팀과 이야기하면서 알게 되었는데 구글 내부적으로는 이 기능을 2분기 계획으로 잡으려고 한다고 했다.

다만 요즘 이래저래 바빠서 2분기까지 완전히 완성하긴 어려울 것 같고, 프로토타이핑 및 문서화 정도까진 가능할 것 같다고 이야기하긴 했는데 얼른 바쁜 게 끝나면 좋겠다.

Feature 구현을 시작하기 전에 간단하게 블로그에 정리해 보았다.