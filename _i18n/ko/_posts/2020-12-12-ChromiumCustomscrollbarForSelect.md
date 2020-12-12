---
layout: post
title: Chromium <select>에 대한 Custom ScrollBar 옵션 적용 구현 
date:   2020-12-12 15:00:20
categories: Chromium
comments: true
languages:
- english
- korean
tags:
- Chromium
- C++
- Web Engine
- HTML/CSS
---

Issue: [http://crbug.com/1076508](http://crbug.com/1076508)

Patches: 

1. [https://chromium-review.googlesource.com/c/chromium/src/+/2364316](https://chromium-review.googlesource.com/c/chromium/src/+/2364316)
2. [https://chromium-review.googlesource.com/c/chromium/src/+/2418527](https://chromium-review.googlesource.com/c/chromium/src/+/2418527)
3. [https://chromium-review.googlesource.com/c/chromium/src/+/2586293](https://chromium-review.googlesource.com/c/chromium/src/+/2586293)

약 3개월 정도 전에 들어간 패치가 실제 라이브 크롬에서 동작한다. 

뭔가 기분이 이상하기도 하고 뿌듯하기도 하다. 

전 세계 사람들이 내가 기여한 내용을 눈으로 보고 쓸 것이라는게 더 기분이 좋은것 같다.

![After patch](/uploads/2020-12-12/1.gif)

이것을 보면 이번에 크롬 버전이 업데이트 되면서 라이브 크롬 버전에 내가 구현한 기능이 동작한다.

이 기능을 구현하기 전 같은 코드는 이렇게 동작했다.

![Before patch](/uploads/2020-12-12/2.gif)

[이 문서에 따르면](https://developer.mozilla.org/en-US/docs/Web/CSS/::-webkit-scrollbar) 크로미움 및 웹킷 기반 웹브라우져에는 위와같이 ::-webkit-scrollbar 옵션을 통해 스크롤바에 CSS 프로퍼티를 적용할 수 있다. 

가장 첫번째 gif 이미지를 동작시키는 스타일이다.

```css
::-webkit-scrollbar {
    width: 10px;
		height:10px;
  }
  ::-webkit-scrollbar-track {
    background: orange;
  }
  ::-webkit-scrollbar-corner {
    background: yellow;
  }

  ::-webkit-scrollbar-thumb {
    background: gray;
  }
  ::-webkit-scrollbar-thumb:hover {
    background: green;
  }
```

기여하기 이전에는 이렇게 하였을 때  다른 곳에서의 스크롤바(ex: 페이지의 스크롤 바)는 위에서 스타일을 적용한 대로 렌더링이 된다. 

![Render example](/uploads/2020-12-12/3.png)

이런식으로 위 코드에 대하여 스크롤바가 잘 적용되었다.

하지만 기존에는 두번째 gif와 같이 \<select>에 대하여 커스텀 스크롤 바가 적용되지 않았다.

이 문제를 해결하는 과정에 대해 이해하려면 \<select>가 어떻게 동작하는지 알 필요가 있다.

우리가 \<select>를 눌렀을 때 브라우져에서는 새로 웹 팝업을 띄운다. 이것을 Chromium에서 Internal Popup이라고 한다. 

그러니까 우리가 \<select>를 눌렀을 때 웹뷰를 하나 새로 만들고, 거기에 html코드를 넣고, 렌더링을 하는 것이 현재의 \<select>가 구현되어 있는 방식이다. 여기서 스타일은  호스트에 정의되어있는 스타일을 Internal Popup에 복사하는 방식으로 구현되어 있다.

자세히 보고 싶으면 [실제 코드](https://source.chromium.org/chromium/chromium/src/+/master:third_party/blink/renderer/core/html/forms/internal_popup_menu.h)를 참고하자. 

하여튼, 

기존의 코드는 element에 대해서 스타일을 적용해 줬지만, pseudo class 스타일인 :-webkit-scrollbar에 대한 스타일 적용기능이 구현되어 있지 않았고, 고려도 되어있지 않았다.

 

ComputedStyle로 부터 문자열 CSS로 시리얼라이즈 한 뒤, Internal Popup에 스타일을 적용시키는  기능을 구현한 것이 이번 기여내용이다.

코드베이스도 코드베이스지만 테스트코드가 왕창 늘어났다.

Added 테그가 붙인게 내가 추가한 파일들이다.

![Added files](/uploads/2020-12-12/4.png)


1번 패치

![Added files](/uploads/2020-12-12/5.png)


2번(Hover 기능) 패치

추가한 테스트 코드가 정말 많다. 그리고 Internal Popup은 다른 팝업이 생성된다는 특수한 케이스라 렌더링을 찍고, 그걸 미리 렌더링 한 이미지를 대상으로 픽셀바이 픽셀로 비교하는 테스트인 픽셀테스트를 사용하여야 했다. 이는 플랫폼별로 약간씩 다르게 렌더링됨을 의미한다. 그것에 대해서 다르지 않도록 불필요한 요소를 제거하는 작업도 주요 포인트였다.

어떤 부분을 수정해야하고, 조사하는 과정에서의 개발 일지는 안써놔서 완성된 상태의 코드를 설명하는 정도로 이 글을 끝낼것이다.

아래부터는 코드레벨의 구현에 대한 이야기다. 

시리얼라이즈를 위한 함수 몇 개를 정의했다.

```cpp
//Computed 스타일을 받고 id에 해당하는 스타일을 Serialize 해주는 함수
const String SerializeComputedStyleForProperty(const ComputedStyle& style,
                                               CSSPropertyID id) {
  const CSSProperty& property = CSSProperty::Get(id);
  const CSSValue* value =
      property.CSSValueFromComputedStyle(style, nullptr, false);
  return String::Format("%s : %s;\n", property.GetPropertyName(),
                        value->CssText().Utf8().c_str());
}
```

```cpp
//Target에 대하여 CSS 요소를 완성시켜주는 함수 (대충 target\n { } \n형식으로 css가 만들어진다
void InternalPopupMenu::AppendOwnerElementPseudoStyles(
    const String& target,
    SharedBuffer* data,
    const ComputedStyle& style) {
  PagePopupClient::AddString(target + "{ \n", data);

  const CSSPropertyID serialize_targets[] = {
      CSSPropertyID::kDisplay,    CSSPropertyID::kBackgroundColor,
      CSSPropertyID::kWidth,      CSSPropertyID::kBorderBottom,
      CSSPropertyID::kBorderLeft, CSSPropertyID::kBorderRight,
      CSSPropertyID::kBorderTop,  CSSPropertyID::kBorderRadius,
      CSSPropertyID::kBoxShadow};

  for (CSSPropertyID id : serialize_targets) {
    PagePopupClient::AddString(SerializeComputedStyleForProperty(style, id),
                               data);
  }

  PagePopupClient::AddString("}\n", data);
}
```

이 함수들은 ComputedStyle로 부터 CSS 텍스트로 변환하고, CSS 스타일로 만들어 Internal Popup에 적용하는 함수들이다.

이것을 사용하여 복사를 하였을 때 스타일이 잘 적용되었다. 다만 :hover 와 같은 Pseudo style은 조금 복잡한 과정을 거쳐야 한다.

Hovered를 구현하기위해 코드를 읽으면서 든 생각은 렌더러쪽에선 hovered가 어떻게 처리되고 있는가(어떤 코드에 의해서 hovered 스타일이 적용되는가? 라는 질문으로 조사를 했고 아래는 그 조사를 기반으로 임시 스크롤바 객체 scroll을 이용하여 hovered 스타일을 가져오는 코드이다.

```cpp
scoped_refptr<const ComputedStyle> StyleForHoveredScrollbarPart(
    HTMLSelectElement& element,
    const ComputedStyle* style,
    Scrollbar* scrollbar,
    PseudoId target_id) {
  ScrollbarPart part = ScrollbarPartFromPseudoId(target_id);
  if (part == kNoPart)
    return nullptr;
  scrollbar->SetHoveredPart(part);
  scoped_refptr<const ComputedStyle> part_style = element.StyleForPseudoElement(
      PseudoElementStyleRequest(target_id, To<CustomScrollbar>(scrollbar),
                                part),
      style);
  return part_style;
}
```

최종적으로 각각의 스크롤 바 스타일에 대하여 적용하는 코드는 다음과 같다.

```cpp
LayoutObject* owner_layout = owner_element.GetLayoutObject();

  std::pair<PseudoId, const String> targets[] = {
      {kPseudoIdScrollbar, "select::-webkit-scrollbar"},
      {kPseudoIdScrollbarThumb, "select::-webkit-scrollbar-thumb"},
      {kPseudoIdScrollbarTrack, "select::-webkit-scrollbar-track"},
      {kPseudoIdScrollbarTrackPiece, "select::-webkit-scrollbar-track-piece"},
      {kPseudoIdScrollbarCorner, "select::-webkit-scrollbar-corner"}};

  Scrollbar* temp_scrollbar = nullptr;
  const LayoutBox* box = owner_element.InnerElement().GetLayoutBox();
  if (box && box->GetScrollableArea()) {
    if (ScrollableArea* scrollable = box->GetScrollableArea()) {
      temp_scrollbar = MakeGarbageCollected<CustomScrollbar>(
          scrollable, kVerticalScrollbar, &owner_element.InnerElement());
    }
  }
  for (auto target : targets) {
    if (const ComputedStyle* style =
            owner_layout->GetCachedPseudoElementStyle(target.first)) {
      AppendOwnerElementPseudoStyles(target.second, data, *style);
    }
    // For Pseudo-class styles, Style should be calculated via that status.
    if (temp_scrollbar) {
      scoped_refptr<const ComputedStyle> part_style =
          StyleForHoveredScrollbarPart(owner_element,
                                       owner_element.GetComputedStyle(),
                                       temp_scrollbar, target.first);
      if (part_style) {
        AppendOwnerElementPseudoStyles(target.second + ":hover", data,
                                       *part_style);
      }
    }
  }
```

이부분이 이번 기여의 스타일을 적용하는 부분이다. ComputedStyle로 부터 타겟 스타일을 serialize 하여 Internal Popup에 집어넣는다.