---
layout: post
title:  Custom Highlight Universal Selector ::highlight(*)
date:   2026-10-20 9:00:00+0900
categories: development
comments: true
languages:
- english
- korean
tags:
- Chromium
- Blink
- CSS
- css-pseudo-4
- Feature
filepath: https://github.com/DevSDK/devsdk.github.io/blob/main/_i18n/ko/_posts/2026-10-20-CSS-Custom-Highlight-Universal-Selector.md
---

최근 CSS Custom Highlight를 위한 Universal Selector `::highlight(*)`를 관련 CSS 표준에 추가하고(대부분 [CSS Custom Highlights](https://drafts.csswg.org/css-highlight-api-1/) 표준이 아닌 [CSS Pseudos](https://drafts.csswg.org/css-pseudo-4/) 표준이 수정됨) Chromium에 구현했고, Chrome 158에서 배포된다. 

이 글에서는 이 기능이 무엇인지, 왜 유용한지 소개한다.

## CSS Custom Highlights란?

CSS Custom Highlights를 사용하면 텍스트를 별도의 요소로 감싸지 않고도 임의의 텍스트 범위에 스타일을 적용할 수 있다.

예를 들면,

```javascript
// ::highlight(search) { background-color: yellow }

const ranges = matchOffsets.map(([start, end]) =>
  new StaticRange({ startContainer: textNode, startOffset: start,
                    endContainer:   textNode, endOffset:   end }))

CSS.highlights.set("search", new Highlight(...ranges))

// DOM 변경 없음: 검색을 다시 실행하면 registry entry만 교체된다
```

`span::highlight(awesome)`이나 `#foo::highlight(bar)`처럼 특정 요소로 범위를 좁힐 수 있다. 

Custom Highlights는 2025년 6월부터 Baseline newly available 상태이므로, 위 코드는 모든 브라우저에서 동작한다.

## 문제점

custom highlight의 이름을 매번 지정해야 한다.

만약 모든 highlight에 적용되는 전역 규칙을 만들고 싶을 때는 어떻게 해야 할까?

마땅한 방법이 현재까진 없다.

예시,

```css
::highlight(spelling) {
  text-decoration-color: yellow;
  text-decoration-line: underline; /* 중복! */
  text-decoration-style: wavy; /* 중복! */
}

/* ... */

::highlight(punctuation) {
  text-decoration-color: red;
  text-decoration-line: underline; /* 중복! */
  text-decoration-style: wavy; /* 중복! */
}
```

중복된 스타일이 20개가 넘는다면 어떨까?
작업이 번거로워지고, 공통 스타일을 바꿀 때마다 여러 곳을 고쳐야 한다.

## `::highlight`를 위한 Universal Selector 도입

이 문제를 해결하기 위해 [CSSWG는](https://github.com/w3c/csswg-drafts/issues/9091) 이름이 지정된 모든 highlight에 매칭되는 `*` 인자를 추가하기로 결정했다.

2026년 9월 30일, 내가 올린 [Spec PR](https://github.com/w3c/csswg-drafts/pull/14301)이 머지됐다.

이제 위 예시는 아래처럼 중복을 제거할 수 있다.

```css
::highlight(*) {
  text-decoration-line: underline;
  text-decoration-style: wavy;
}

::highlight(spelling) {
  text-decoration-color: yellow;
}

::highlight(punctuation) {
  text-decoration-color: red;
}
```

결과는 앞의 중복된 버전과 같다. 이름이 지정된 모든 custom highlight(spelling, punctuation)가 universal(`*`) 규칙의 스타일을 사용하기 때문이다.

### `::highlight(*)`의 specificity는 0이다

[CSS Selectors](https://drafts.csswg.org/selectors/#specificity-rules)에는 각 규칙의 "가중치"를 계산해 어떤 selector가 우선하는지 결정하는 specificity 알고리즘이 있는데, 간단하게 말해서 두 규칙이 같은 속성을 지정하면 cascade는 specificity를 기준으로 어느 쪽이 이길지 결정한다. 자세한 내용은 [MDN 문서](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Cascade/Specificity)를 참고.

현재 널리 쓰이는 highlight(custom ident를 쓰는 경우)는 태그 이름과 같은 specificity를 가진다. 하지만 `*`를 쓰는 highlight는 specificity가 0이 되도록 바꿨다.

구현 사이드에서는 인자가 `*`일 때 명시적으로 0을 반환한다:

```cpp
inline unsigned CSSSelector::SpecificityForOneSelector() const {
	// ...
    case kPseudoHighlight:
          if (Argument() == UniversalSelectorAtom()) {
            return 0;
          }
          [[fallthrough]];
```

0은 가장 낮은 specificity이므로 이름이 있는 custom highlight가 항상 이긴다. (단, `p::highlight(*)`는 `p`의 specificity가 더해져 `::highlight(foo)`와 동등해진다.)

예를 들면,

```css
::highlight(*) {
	color: red; /* 패배... */
	background-color: blue;
}

::highlight(foo) {
	color: green; /* 승리! */
}
```

따라서 `foo`에는 최종적으로 `color: green`과 `background-color: blue`가 적용된다.

### fallback

`::highlight(*)`를 쓰면 등록된 모든 highlight가 universal 규칙을 기본 스타일처럼 사용한다.

예를 들면:

```html
<style>
::highlight(*) {
    color: red;
}
</style>

<p id="target">Hello, highlights!</p>

<script>
  const range = new Range();
  range.selectNodeContents(document.getElementById("target"));
  CSS.highlights.set("bar", new Highlight(range));
</script>
```

등록된 custom highlight `bar`는 universal 규칙을 따르므로 `color: red`로 그려진다.

API에 대한 더 자세한 내용은 MDN을 참고(아직 업데이트 안 돼 있을 수 있음): [CSS Custom Highlight API](https://developer.mozilla.org/en-US/docs/Web/API/CSS_Custom_Highlight_API)

이 기능은 Chrome 158에 포함되어 2026년 11월 4일에 출시될 예정이다. 자세한 내용은 [Chrome Platform Status 항목](https://chromestatus.com/feature/5174965228929024)과 [구현 CL](https://chromium-review.googlesource.com/c/chromium/src/+/8235619)에서 확인할 수 있다.

## 마치며

Spec 수정부터 기능 출시까지 직접 작업할 수 있어서 정말 기쁘다!

Spec PR을 리뷰해 준 fantasai, Chromium 패치를 리뷰해 준 Rune, 그리고 Igalia 동료 Stephen에게 감사한다. 이 작업은 Bloomberg의 후원으로 진행됐다.