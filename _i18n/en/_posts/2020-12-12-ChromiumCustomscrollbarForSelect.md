---
layout: post
title: Implement the \<select> should be affected by custom scrollbar tags  
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

The Implemented feature that I implemented 3 months ago is now working on Google Chrome live version.

It's a gratified thing and sometimes I felt it's unreal.

My achievement could be used for people all around the world. How awesome.

![After patch](/uploads/2020-12-12/1.gif)

This gif image indicates after updated chrome working my code.

Previously, the same codes working like this:

![Before patch](/uploads/2020-12-12/2.gif)

According to [this document](https://developer.mozilla.org/en-US/docs/Web/CSS/::-webkit-scrollbar), Chromium and WebKit based browsers support the custom scrollbar via ::-webkit-scrollbar in CSS pseudo element.

The first gif image's CSS code:

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

In the previous version, other places (not \<select>, i.e. Page's scrollbar ) are ideally rendered as we expected like:

![Render example](/uploads/2020-12-12/3.png)

However, Before the change, we could see unexpected results for \<select> on the second gif image.

Before understanding, we should know about how \<select> work on chromium.
When we clicked the \<select>, The browser (chromium) opened a new web popup(Simply, new web renderer). We called 'Internal Popup".
In other words, The html codes and some internal styles from the host are copied to a new webview 'Internal Popup' and rendering via web-engine blink, when we clicked \<select>.

If you want to see detailed implementation, [Source codes are here.](https://source.chromium.org/chromium/chromium/src/+/master:third_party/blink/renderer/core/html/forms/internal_popup_menu.cc)

Before the CL, the simple element styles are implemented (i.e. background color for options). But The function of Pseudo class style like ':-webkit-scrollbar' is not implemented and also not considered.
 

This patch mainly implements the serializer from ComputedStyle to CSS string and applies to internal popup.

The test codes are dozen.

"Added" tags indicates added test codes.

![Added files](/uploads/2020-12-12/4.png)

First patch

![Added files](/uploads/2020-12-12/5.png)

Second (:hover) patch

Many tests are added. Because It's a special test case that opened a new Internal Popup, We should use a pixel test that compares pixel by pixel difference between pre-rendered image and actually rendered pixels. This case could bring platforms difference. So one of the tasks on this patch is to reduce platform difference.

I didn't write a detailed devlog. So, I've written completed codes and explain not kind of inspection or debugging parts.

Below is the code-level implementation section.

Declare few functions for serialization.

```cpp
//Serialize function from Computed to String CSS property via property-id.

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
//Function that builds CSS element (i.e. target\n{ ~some css~ } \n)
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

These functions use to serialize ComputedStyle to CSS style string and then apply to Internal Popup.

With this, it has worked properly until without  ':hover'.
Pseudo style like ':hover' is rather complicated.

When I read codes to implement ':hover', I have a question "how to work in the renderer when ':hover'?" And I could figure out ':hover' ComputedStyle could be serialized on hover status for the element. And the below codes is the answer after inspection:

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

Finally, The code for each scrollbar styles is:

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
Internal Popup's style filled out from above serialization functions.