---
layout: post
title: I released CSS Trigonometric Functions
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

I released the project "CSSTrigonometricFunctions" which is implementing the trigonometric functions to CSS on Chromium.

I have released the second feature that has a feature flag to chromium working as a hobby at the extra times kind of after/before work and weekends.

CSS Trigonometric Functions project is to implement the following functions:

MDN: https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Functions#trigonometric_functions
- [sin()](https://developer.mozilla.org/en-US/docs/Web/CSS/sin)
- [cos()](https://developer.mozilla.org/en-US/docs/Web/CSS/cos)
- [tan()](https://developer.mozilla.org/en-US/docs/Web/CSS/tan)
- [asin()](https://developer.mozilla.org/en-US/docs/Web/CSS/asin)
- [acos()](https://developer.mozilla.org/en-US/docs/Web/CSS/acos)
- [atan()](https://developer.mozilla.org/en-US/docs/Web/CSS/atan)
- [atan2()](https://developer.mozilla.org/en-US/docs/Web/CSS/atan2)

These functions are defined in w3c / [css-values-4](https://www.w3.org/TR/css-values-4/#trig-funcs) specification.

The CSS trigonometric function is an implementation of css-values-4 spec. In 2018, The first draft of css-values-4 was released by w3c, and in 2020 they introduced the trigonometric functions chapter ”11.4. Trigonometric Functions: sin(), cos(), tan(), asin(), acos(), atan(), and atan2()”.

At the beginning of this year, I planned to implement this feature. But there are some issues like the codebase conflicts with refactoring so I could start in July.
 This feature took [formal chromium feature implementation steps](https://www.chromium.org/blink/launching-features/#implementations-of-already-defined-consensus-based-standards) including [intent to prototype](https://groups.google.com/a/chromium.org/g/blink-dev/c/-c9p-Sq_gWg/m/C9eOR3oGAgAJ), [intent to ship](https://groups.google.com/a/chromium.org/g/blink-dev/c/UiUVU722BbU/m/vQJy-qdpDAAJ), and 3 approved by other committers.
 I merged [the CL about enabling by default the feature flag](https://chromium-review.googlesource.com/c/chromium/src/+/4085177) CSSTrigonometricFunctions after 3 approval. In chrome 111, this feature will be included.

You can use it on Chrome 111 (Beta: Feb 9 - Feb 16, Stable: Mar 1)

The main changes were the creation of the function that evaluates and process the trigonometric functions. Per one CL(like PR) handled one trigonometric function with implementing WPT test code.

Resolving relative length on atan2() has tricky problems (especially, evaluating relative length in parsing time). So, Using its double value for now.

This issue occurred in other mainstream browsers gecko, webkit.
W3C/CSSWG is discussing this issue.

Related issues::

- Crbug: [https://crbug.com/1392594](https://bugs.chromium.org/p/chromium/issues/detail?id=1392594)
- Webkit Bugzilla: [https://bugs.webkit.org/show_bug.cgi?id=248513](https://bugs.webkit.org/show_bug.cgi?id=248513)
- Gecko Bugzilla: [https://bugzilla.mozilla.org/show_bug.cgi?id=1802744](https://bugzilla.mozilla.org/show_bug.cgi?id=1802744)
- W3C/CSSWG: [https://github.com/w3c/csswg-drafts/issues/8169](https://github.com/w3c/csswg-drafts/issues/8169)