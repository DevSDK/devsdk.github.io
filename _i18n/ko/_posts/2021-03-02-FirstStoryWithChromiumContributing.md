---
layout: post
title: Chromium 첫번째 패치부터 지금까지 돌아보기
date:   2021-03-02 08:02:20
categories: development
comments: true
languages:
- korean
tags:
- Chromium
- Open Source
---		

Chromium에서 활동한지 반년정도 되어가는 것 같고, 11개의 패치를 머지시켰다. 

라인수로는 정확하지는 않지만 1600라인 넘게 수정한 것 같다.

![Screenshot_from_2021-03-02_12-56-55](https://user-images.githubusercontent.com/18409763/109617938-5360a000-7b7a-11eb-86a0-1bd7d6d20773.png)

그중의 하나인 첫 패치는 deprecated된 메크로 함수를 지우는 오타 수정과 비슷한 패치 trivial 패치여서 제외하면 10개에 도달한 것 이다.

이 말은 [커미터가 되기 위한 조건](http://www.chromium.org/getting-involved/become-a-committer) 중 첫 번째를 달성했다는 것 이다. 

`10-20 non-trivial patches in the Chromium src Git repository`


2~3개월 내로 커미터를 달 수 있을 것 이라고 기대하고 있는데, 언제 노미네이션 될지는 잘 모르겠다.

*크로미움 이메일 주소 가지고 싶다....*

### 웹브라우져를 만들자

사실 Chromium 건들기 시작하게 된 계기는 반년 전이 아니라 1년 전 이다. 친한 형하고 놀면서 (프론트엔드 개발자) 이야기 하다가 웹브라우져를 이해하기 위해 웹브라우져를 만드는 프로젝트를 해보고 싶다는 대화가 오고 갔다.

 그렇게 웹브라우져의 코드를 분석하고 서로 공유하는 팀인 team_seoksoo (친한 형 이름이 '영수'라 내 이름의 석과 형 이름의 수를 붙여 만들었다.)를 만들게 되었다.

시작부터 수월하지는 않았다. 상대는 3000만 라인이 넘는 거대한 오픈소스 프로젝트 Chromium과 하나부터 알아가야 했던 WebKit이였기 때문이다.

첫번째로 직면했던 문제중 하나는 레포 덩치가 어마어마하다는 것 이다. 

[여기](https://chromium.googlesource.com/chromium/src/+/master/docs/linux/build_instructions.md)서 볼 수 있는 Chromium의 권장 빌드 스팩은 다음과 같다.

- A 64-bit Intel machine with at least 8GB of RAM. More than 16GB is highly recommended.
- At least 100GB of free disk space.
- You must have Git and Python v2 installed already.

실제로 내 컴퓨터에서는 150GB (...) 정도를 크로미움이 먹고 있다.

빌드하는데는 3시간정도 걸린다. (XPS 9560 최고급모델, i7 7700HQ, 32GB) 

![Untitled](https://user-images.githubusercontent.com/18409763/109617999-66737000-7b7a-11eb-9fae-0f4199fe7f27.png)
)

*이 글을 쓰기 한참 전부터 빌드를 돌려놨는데 아직도 끝나지 않았다..*

우여곡절 끝에 코드를 받고 빌드해서 실행까지 해내는데 성공했고, 그 시기에 Blink Renderer의 정수가 담긴 문서 "[Life of Pixels](http://bit.ly/lifeofapixel)"를 보게 되었다. "웹브라우져가 구체적으로 어떻게 동작하는 구나~" 라는 것을 배울 수 있던 시기였다.

idl에 대해 배우고, 콘솔에 로그 찍어보고, 여타 다른 것들 분석하듯이 분석하다가,  자연스럽게 다른 task들의 비중이 높아지고, 팀의 의욕이 줄어들어서 (서로 본업과, 학업 및 기타등등) 멈춘 것 같다. 그렇게 2학년 1학기가 흘러갔다. 

### 본격적인 시작

Chromium 활동에 불이 다시 붙은건 2학년 여름방학이였다. 컨트리뷰톤이라는 활동에서  Chromium 팀에 선정되었다. 대단한 멘토분들 (hyunjune.kim&samsung.com,jh718.park&gmail.com) 이 컨트리뷰션 프로세스에 대해 잘 알려주고 간단한 trivial issue를 지정해줘서 전체적인 컨트리뷰션 프로세스를 경험할 수 있었다.

그리고 GoodFirstBug 라는 테그를 이용해 초심자가 해결 하기 좋은 이슈 내역을 찾아다녔다.

(그렇게 나는 속았다.) 사실 GoodFirstBog로 분류된 이슈 중에서는 사실 GoodFirstBug가 아닌 경우도 꽤 많고, 까고 보니까 규모가 커지는 경우도 많은 것 같다.

컨트리뷰톤 내내 잡고 있던 이슈는 select의 스크롤바 이슈를 해결하는 것, 이 내용에 대해서는 [이 글에](https://devsdk.github.io/ko/chromium/2020/12/13/ChromiumCustomscrollbarForSelect.html) 나와있다. 놀랍게도 GoodFirstBug였다.

이 패치 말고도 html form의 validation message를 수정하는 등의 패치를 이어나갔다.

그렇게 패치를 이어나가고, 3~4패치가 머지 되었을 때 멘토님이 커미터 분들한테 프로젝트 맴버 권한을 요청해주셨다.

그렇게 받은 권한들.

![permissions](https://user-images.githubusercontent.com/18409763/109618232-a33f6700-7b7a-11eb-992d-5a754dfe5c23.png)

 tryjob-access: [testfarm](https://ci.chromium.org/p/chromium)에 테스트를 실행하고 코드 리뷰를 받고 내 패치를 **머지**시킬 수 있는 권한

edit-bug-access: [https://crbug.com/](https://crbug.com/) 에 올라온 모든 이슈를 직접 **수정**할 수 있는 권한. (이 권한이 있어야만 볼 수 있는 이슈도 있음).

*이 권한들이 있고 없고의 차이가 꽤 크다고 생각한다.*

권한을 받고 활동을 하면서 욕심이 생겼다. 원동력이 된 것들은 다음과 같다.

- 영어를 계속 사용할(사용해야만) 환경
- 디버깅 능력을 입증할 수 있는 기회
- 모두가 쓰는 sw를 개발한다는 것에 대한 자부심
- 코드를 읽고 수정하는 능력 향상 및 증명
- 전 세계의 훌륭한 개발자들과의 협업
- 맡은 것에 대한 책임감
- 프로젝트 맴버로써 받은 권한에 대한 자부심
- 탐나는 ssh&chromium.org 커미터 이메일 (중요한 동기부여라고 생각한다)
- 취업에 도움이 될 것
- 좋은 코드를 유지하는 방법에 대해 코드 리뷰를 받으며 성장 기회
- 그리고.... **재미있다**.

계속 커밋을 하고 리뷰를 받으며 점점 "내가 Owner로 마크한 이슈들을 해결하는 것"에 책임감을 가지고 조금 더 나은 방향과 좋은 구조를 항상 고민할 수 있게 되었다.

디버깅 관련 지식이 많이 늘어났다.

 chrome://tracing 에서 트레이싱 할 수 있는 것들이 정확히 어느 시점에서 (브라우져 내부에서) 기록이 되고 있는지를 그리고 -show-paint-rects와 같은 실제로 draw가 일어나는 영역에 대한 디버깅 관련한 지식을 3D Preserve 관련 패치를 하면서 살펴볼 수 있었다.

![Peek 2020-09-14 15-08](https://user-images.githubusercontent.com/18409763/109618315-bbaf8180-7b7a-11eb-95d7-1fcbc1159ff0.gif)


### Chromium 개발은 꾸준히 진행중!

그러다가 현재에 와서, Chromium에 정식 기능 추가 절차를 밟으며 CSS에 기능을 추가하는 **"프로젝트"**를 진행하게 되었다. 처음에는 작은 이슈에 대한 간단한 패치였지만, 이 내용이 커지고 CSS 전반적으로 영향을 미치게 되면서 프로젝트가 되었다.

Chromium에 feature 도입 상태에 대해 볼 수 있는 곳 Chromium Feature Status 에 정식으로 [등록되어](https://chromestatus.com/feature/5657825571241984) 었다.

이 프로젝트를 진행하며 [Design Docs](https://bit.ly/349gXjq)를 쓰게 되었는데, 논의가 필요한 부분이 있어서 구글 본사 Chrome 팀 직원분과 Google Meet을 통해 화상통화를 하며 프로젝트에 대해 논의하는 어찌보면 꿈과 같은 경험을 하게 되었다. 

![googlemeet](https://user-images.githubusercontent.com/18409763/109618401-d97ce680-7b7a-11eb-99d5-3486e6234614.png)

![googlemeet2](https://user-images.githubusercontent.com/18409763/109618399-d84bb980-7b7a-11eb-96f9-aec6610565b6.png)


 화상회의 한번으로 프로젝트의 진행 방향을 어느정도 정리 할 수 있었다. 

(여러 패치로 나누는 것, W3C의 스팩이 부족한점이 있어서 논의가 필요한 부분이 있다는 것, 이 값에 대한 "animation" 에서의 "보간"에 대해 추후에 논의가 필요할 것 같다 등등)

이 프로젝트는 현재 진행형이다. 3개의 패치가 이 프로젝트에 대한 패치이다.

어떤 기능을 함께 만들어나간다 라는 기쁨을 온몸으로 즐기고 있다.

느낀것 혹은 얻은것은 다음과 같다.

* Fully Test driven의 이점과 3000만 라인의 거대한 프로젝트가 높은 퀄리티로 유지되는 방법
* 웹 표준의 중요성. Browser간의 interoperability를 생각하는 능력
* 개발자를 위한 좋은 인프라가 생산성에 어떤 이점을 주는지 ([Chromium Source Search](https://source.chromium.org/chromium/chromium/src/+/master:third_party/blink/renderer/core/css/css_value_clamping_utils.h))
* Code-review의 순기능
* Blink-dev에 새로 나오는 기능을 살펴보는 습관
* 웹으로 무엇이든 할 수 있게 될 것이라는 생각
* 매우 높은 수준의 개발자들과의 협업
* 생각보다 웹브라우져에는 버그가 많다 (특히 scroll 쪽 이슈들 )

혹시 이 글을 보고 Chromium에 흥미가 생겼다면, 오픈소스 개발자의 문은 언제나 열려있다! 누구든 같이 Chromium을 개발하면 좋겠다.

취준생이 되서 개인프로젝트도 진행하며 바빠지고, 불안함이 많아졌지만 시간 날때마다 책임감을 가지고 활동을 이어나가고 있다.