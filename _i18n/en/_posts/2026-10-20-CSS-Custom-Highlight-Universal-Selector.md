---
layout: post
title: Custom Highlight Universal Selector ::highlight(*)
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
filepath: https://github.com/DevSDK/devsdk.github.io/blob/main/_i18n/en/_posts/2026-10-20-CSS-Custom-Highlight-Universal-Selector.md
---

I recently added a universal selector for CSS custom highlights, `::highlight(*)`, to the relevant CSS Specifications (the bulk of it is actually in [CSS Pseudos](https://drafts.csswg.org/css-pseudo-4/) not [CSS Custom Highlights](https://drafts.csswg.org/css-highlight-api-1/)) and implemented it in Chromium.

It will ship in Chrome 158. This post introduces what it is and why it's useful.


## What are CSS Custom Highlights?

CSS Custom Highlights allow you to style arbitrary ranges of text without wrapping them in extra elements.

For example, you can write it for searching text:

```javascript
// ::highlight(search) { background-color: yellow } 

const ranges = matchOffsets.map(([start, end]) =>
  new StaticRange({ startContainer: textNode, startOffset: start,
                    endContainer:   textNode, endOffset:   end }))

CSS.highlights.set("search", new Highlight(...ranges))

// No DOM mutation: re-running the search replaces the registry entry
```

Note that this is a pseudo-element, so you can scope it to an element, like `span::highlight(awesome)` or `#foo::highlight(bar)`.

Custom Highlights have been Baseline newly available since June 2025, so every browser is shipping support for the above.

## What's the problem?

Until now, authors had to give a specific custom highlight name.

But... what if we want to create a global rule that applies to all of the highlights?

We had no particular way to reduce duplication.

For example:

```css
  
::highlight(spelling) {  
  text-decoration-color: yellow;
  text-decoration-line: underline; /* Duplicated! */
  text-decoration-style: wavy; /* Duplicated! */
}

/* ... */

::highlight(punctuation) {
  text-decoration-color: red;
  text-decoration-line: underline; /* Duplicated! */
  text-decoration-style: wavy; /* Duplicated! */
}
```

What if we need to change more than 20 duplicated styles?
This gets tedious, and it means that every shared change has to be made in several places.

## Introducing a Universal Selector for `::highlight`

To solve the problem, [CSSWG resolved](https://github.com/w3c/csswg-drafts/issues/9091) to add a `*` argument that matches every named highlight. 

On September 30, 2026, my [spec PR](https://github.com/w3c/csswg-drafts/pull/14301) was merged.

Now the example above becomes:


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

The result is the same as the above duplicated version, because all named custom highlights (spelling, punctuation) will use the styles from the universal (`*`) one. 

Simple, isn't it?

### `::highlight(*)` has zero specificity

[CSS Selectors](https://drafts.csswg.org/selectors/#specificity-rules) has a specificity algorithm that is used to calculate the "weight" of each rule, in order to determine which selector has more priority.

Simply, when two rules set the same property, the cascade uses specificity to decide which one wins. See the detail in the [MDN docs](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Cascade/Specificity).

Highlights as widely deployed today (with a custom ident) have a specificity equivalent to using a tag name. However, we have modified that so that highlights using `*` have zero specificity.

On the implementation side, I explicitly return 0 when the argument is `*`:
```cpp
    
inline unsigned CSSSelector::SpecificityForOneSelector() const {
	// ...
    case kPseudoHighlight:
          if (Argument() == UniversalSelectorAtom()) {
            return 0;
          }
          [[fallthrough]];
```


Since zero is the lowest specificity, named custom highlights always win. (But `p::highlight(*)` ties with `::highlight(foo)`, since `p` has the equivalent specificity.)

For example:

```css
::highlight(*) { 
	color: red; /* LOSE... */
	background-color: blue;
}

::highlight(foo) {
	color: green; /* WIN! */
}
```

So `foo` ends up with `color: green` and `background-color: blue`.

### A fallback for every highlight
A highlight with no matching `::highlight()` rule paints nothing. 
With `::highlight(*)`, every registered highlight falls back to the universal rule, like a default custom highlight.

For example:
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

The registered custom highlight `bar` will paint `color: red` because it falls back to the universal one.

For more on the API, see MDN [CSS Custom Highlight API](https://developer.mozilla.org/en-US/docs/Web/API/CSS_Custom_Highlight_API) (it may not be updated yet).

On October 20, 2026, the Intent to Ship received three LGTMs from the Blink API owners, and I merged the shipping CL. This feature will be shipped in Chrome M158, scheduled for November 4, 2026.

You can find the details in the [feature entry](https://chromestatus.com/feature/5174965228929024), the [feature implementation](https://chromium-review.googlesource.com/c/chromium/src/+/8235619), and the [DevTools support implementation](https://chromium-review.googlesource.com/c/devtools/devtools-frontend/+/8577240).

## Acknowledgments

I’m thrilled to have worked on this from spec to shipping.

Thanks to fantasai for reviewing the specification, to Rune for reviewing the Chromium patches, and to my colleague Stephen at Igalia. This work was funded by Bloomberg.



