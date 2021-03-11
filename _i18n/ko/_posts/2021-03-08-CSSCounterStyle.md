---
layout: post
title: CSS @counter-style
date:   2021-03-11 00:00:01
categories: development
comments: true
languages:
- korean
tags:
- Chromium
- Chrome
- CSS
---	

오늘 아침 Blin-Dev Group에서 I2S를 보고 재밌는 CSS Feature가 Ship되는걸 보아서 간단히 메모한다.

![Untitled](https://user-images.githubusercontent.com/18409763/110739167-fea4df80-8273-11eb-8cf5-0cae939349db.png)

꾸준히 내가 진행중인 CSS Feature를 리뷰해주고 계신 Xiaocheng이 ship 한 기능이다.

Firefox에서는 2014년부터 이미 지원되는 기능이였던 것 같다.

[https://developer.mozilla.org/en-US/docs/Web/CSS/@counter-style](https://developer.mozilla.org/en-US/docs/Web/CSS/@counter-style)

[표준에 따르면](https://drafts.csswg.org/css-counter-styles-3/#the-counter-style-rule) 아주다양한 방식으로 사용될 수 있을 것 같다.

```css
@counter-style footnote {
  system: symbolic;
  symbols: '*' ⁑ † ‡;
  suffix: " ";
}
It will then produce lists that look like:
*   One
⁑   Two
†   Three
‡   Four
**  Five
⁑⁑  Six
```

![Untitled 1](https://user-images.githubusercontent.com/18409763/110739184-082e4780-8274-11eb-8719-9f41aec52665.png)


근 시일내 당장 쓸 수는 없고, M91버전부터 사용할 수 있을 것 같다.