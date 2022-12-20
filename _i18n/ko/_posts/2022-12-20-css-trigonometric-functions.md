---
layout: post
title: CSS 삼각 함수를 배포했다
date:   2022-12-20 00:00:01
categories: development
comments: true
languages:
- english
- korean
tags:
- Chromium
- Chrome
- CSS
- Feature
- css-values-4
---	

<img width="402" alt="Screenshot 2022-12-20 at 9 08 24 AM" src="https://user-images.githubusercontent.com/18409763/208580491-09ba5854-aa6a-4149-b305-b9b5b271cfae.png">

Feature Entry: https://chromestatus.com/feature/5165381072191488

7월쯤 시작한 Chromium에 CSS에 삼각함수를 구현하는 프로젝트 “CSSTrigonometricFunctions”를 마무리했다.

취미개발로 주로 일요일과 출근시간 전, 퇴근 후 작업했다.

CSS 삼각함수는 다음의 함수를 구현하는 프로젝트다.

MDN: https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Functions#trigonometric_functions
- [sin()](https://developer.mozilla.org/en-US/docs/Web/CSS/sin)
- [cos()](https://developer.mozilla.org/en-US/docs/Web/CSS/cos)
- [tan()](https://developer.mozilla.org/en-US/docs/Web/CSS/tan)
- [asin()](https://developer.mozilla.org/en-US/docs/Web/CSS/asin)
- [acos()](https://developer.mozilla.org/en-US/docs/Web/CSS/acos)
- [atan()](https://developer.mozilla.org/en-US/docs/Web/CSS/atan)
- [atan2()](https://developer.mozilla.org/en-US/docs/Web/CSS/atan2)

함수들은 [css-values-4](https://www.w3.org/TR/css-values-4/#trig-funcs) 스팩에 정의되어 있다.

 2018년에 W3C 스팩 초안이 만들어졌고, 2020년에 기능을 정의하는 삼각함수 챕터 ”11.4. Trigonometric Functions: sin(), cos(), tan(), asin(), acos(), atan(), and atan2()” 가 등장했다. 

올해 초 구현을 계획하다 리팩토링이 겹쳐 다른 작업들 위주로 개발하다 7월부터 실제 구현을 시작한 프로젝트로, [Chromium 정식 기능개발 과정](https://www.chromium.org/blink/launching-features/#implementations-of-already-defined-consensus-based-standards)인 [Intent to prototype](https://groups.google.com/a/chromium.org/g/blink-dev/c/-c9p-Sq_gWg/m/C9eOR3oGAgAJ)과 [Intent to Ship](https://groups.google.com/a/chromium.org/g/blink-dev/c/UiUVU722BbU/m/vQJy-qdpDAAJ) 그리고 3명의 커미터의 approved를 받아 stable로 전환하는 배포 CL이 머지되어 배포되었고, Chrome은 111 버전에 이 커밋이 포함되어 배포가 된다. 

Chrome  111 버전은 2월 9일부터 16일까지 beta를 거쳐 3월 1일부터 일반 사용자들에게 업데이트 된다.

구현시 주요 내용은 삼각함수를 평가/처리하는 함수를 생성하고, 그 함수 내에서 각 함수별 처리를 추가하는 작업이 진행되었다. 삼각함수 하나당 하나의 CL(like PR)로 다뤄졌고, 관련한 WPT 테스트케이스들을 추가하게 되었다.

atan2의 경우 현재 releative-length를 처리하는 것에 기술적인 이슈(특히, 파싱 타임에서 평가가 불가능해지는 점이)들이 존재해 relative 단위를 평가/처리 하지 않고, 그냥 자신의 값을 반환하게 구현했다. 

이는 주요 브라우저 엔진들인 webkit, gecko 도 동일하며, 관련한 이슈 이야기가 W3C/CSSWG 에서 논의되고 있다.

이슈들 모아보기:

- Crbug: [https://crbug.com/1392594](https://bugs.chromium.org/p/chromium/issues/detail?id=1392594)
- Webkit Bugzilla: [https://bugs.webkit.org/show_bug.cgi?id=248513](https://bugs.webkit.org/show_bug.cgi?id=248513)
- Gecko Bugzilla: [https://bugzilla.mozilla.org/show_bug.cgi?id=1802744](https://bugzilla.mozilla.org/show_bug.cgi?id=1802744)
- W3C/CSSWG: [https://github.com/w3c/csswg-drafts/issues/8169](https://github.com/w3c/csswg-drafts/issues/8169)