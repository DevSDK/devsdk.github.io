---
layout: post
title: Allow Infinity And NaN on Chromium CSS - 1
date:   2020-12-23 15:00:20
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
- InfinityAndNaN
- DevLog
---

Issue: [http://crbug.com/1076508](http://crbug.com/1133390)

Patches: 

1. [https://chromium-review.googlesource.com/c/chromium/src/+/2465414](https://chromium-review.googlesource.com/c/chromium/src/+/2465414)


I'll write down to this blog about the log of activity on Chromium project. 

Due to this is a function implementation, The article could be separated. 

This article contains an inspection and research log about the function implementation.

[https://developer.mozilla.org/en-US/docs/Web/CSS/calc()](https://developer.mozilla.org/en-US/docs/Web/CSS/calc())

There are calc function in CSS.

The example of usage 'calc':

```css
div {
	width: calc(10*2px);
}
```

The result of above will be 20px for width property.

Following article will describe feature implementation for this function.

When I've been trying to find something to do on chromium monorail, I've found this issue.

I could've seen the simplest body of issue. I thought this is kind of easy and straightforward.

```
I'm told that per the spec, calc(1px/0) should compute to infinity and not be a parse error.

Testcase:
<div style="width: calc(1px/0); height: 10px; background: green;"></div>
http://plexode.com/eval3/#s=aekVQXANJVQMbAx1yAXgePQOCGwFEQk1ECRJRWRARChwBg50SEaWqi51IU0ZGTxyaHx0Qch8DXgA=
```

These lines of words are the start point of our project.

When I find this issue, I've read the spec. CSS3 and MDN say "Zero division should be ignored". So, I've created a question for the author "Due to the spec, Zero division should be ignored. Could you give me the spec about this issue?" 

And I can get a response from the question. "CSS Values and Units Module Level 4". Following the spec, 'infinity' and 'NaN' should be supported on calc function.
So, I've put my name on the owner and tried inspection.


Firstly I did is trying to find where the calc function was evaluated.

The basic idea was:

'calc function should be parsed on CSS Parser'

Following grep command reduces the enormous search result.

So I've read source codes in parser directory.

To describe below commend, commend will search 'calc(' and ignore character case and only -.cc files exclude -test.cc files.

```bash
grep 'calc(' -rni --include=*.cc --exclude=*test.cc
```

![1.png](/uploads/2020-12-23/1.png)

I've found the comment as I highlighted above. 

For now, it could have been possible to search via identifier constant like k'Token' (i.e. kCalc) Because the chromium project maintains identifiers using json5 files.

Inside of them:

![2.png](/uploads/2020-12-23/2.png)

We could find the source code. Simply, We could search kCalc constant usages to figure out where the expression is evaluated.


![3.png](/uploads/2020-12-23/3.png)

There are about 10 files related to kCalc. And we could find the evaluation part in ‘third_party/blink/renderer/core/css/css_math_expression_node.cc’. (I guess we could find what we want like this way)

the calc function calculates the four fundamental operations recursively. This is an enjoyable part :) .

Simply, Parse function called→Additive function called→Multiplicative function called → Parse function called(Recursion). 

Actually, These implementations are declared on the specification.

Following is the notation in the spec.

![4.png](/uploads/2020-12-23/4.png)

![5.png](/uploads/2020-12-23/5.png)


[I’ll leave the URL]([https://source.chromium.org/chromium/chromium/src/+/master:third_party/blink/renderer/core/css/css_math_expression_node.cc;l=1101;) of the detailed implementation above. If you are interested, please click the link and see the source codes. And I think this is great entry point of this issue.

Now we can implement infinity and NaN using the token on the part of the calculation.

 Actually, In the first CL, I didn't notice I should implement 'NaN' in the code level. After code review, 'NaN' is added. Therefore, In this article, didn't show 'NaN'. 

Followed the function calls, We could get:
![6.png](/uploads/2020-12-23/6.png)

The calculation part.

Let’s think simply. Returning ‘std::numeric_limits<double>::infinity()’ if op is ‘CSSMathOperator::kDivide’. That’s a kind of solution.

Therefore I've added like:
![11.png](/uploads/2020-12-23/11.png)

For the token:

![7.png](/uploads/2020-12-23/7.png)

I thought We should return the value with the token string is ‘infinity’ or ‘-infinity’ or ‘nan’.

#### Test codes

I’ve written the test code.

The problems with writing source codes are wpt test failure because there are different results not implemented ‘round’ function and failure blink_unittests cause the test used other codes.

On blink_unittests, the expressions are parsed by sizes_math_function_parser. So the tests are existed in sizes_math_function_parser_test.cc.

![8.png](/uploads/2020-12-23/8.png)

This tests are evaluated 'CalcToReversePolishNotation' function in 'third_party/blink/renderer/core/css/parser/sizes_math_function_parser.cc' . And The parser is implemented by stack. So we need to add our case. AppendInfinity() denotes add infinity into the stack.

We could see the case in switch expression:


```cpp
case kIdentToken:
        if (EqualIgnoringASCIICase(token.Value(), "infinity") ||
            EqualIgnoringASCIICase(token.Value(), "-infinity")) {
          AppendInfinity(token);
          break;
        }
        return false;
```
One of the problems with unittest is resolved.

And I added new test cases in blink_web_tests. 

There are javascript based tests. I've used dumpAsText() function that generates or compares the text-based result (-expected.txt) from the DOM rendered page.

Following is the new test file in blink/web_tests/css3/calc/calc-infinity.html:
```html
<!DOCTYPE HTML>
<div id="dummy"></div>
<div id="results">Calc could handle an infinity value<br><br></div>
<script>
if (window.testRunner)
    testRunner.dumpAsText();

var tests = [
    "1px * infinity / infinity",
    "1px * 0 * infinity",
    "1px * (infinity + -infinity)",
    "1px * (-infinity + infinity)",
    "1px * (infinity - infinity)",
    "1px * infinity",
    "1px * -infinity",
    "1px * (infinity + infinity)",
    "1px * (-infinity + -infinity)",
    "1px * 1/infinity",
    "1px * infinity * infinity",
    "1px * -infinity * -infinity",
];

var results = document.getElementById("results");
var dummy = document.getElementById("dummy");
for (var i = 0; i < tests.length; ++i) {
    var expression = tests[i];
    dummy.style.width = 'calc(' + expression + ')';
    results.innerHTML += expression + " => " + dummy.style.width + "<br>";
}
</script>
```

The result of above are saved as 'blink/web_tests/css3/calc/calc-infinity-expected.txt':

```
Calc could handle an infinity value

1px * infinity / infinity =>
1px * 0 * infinity =>
1px * (infinity + -infinity) =>
1px * (-infinity + infinity) =>
1px * (infinity - infinity) =>
1px * infinity => calc(infpx)
1px * -infinity => calc(-infpx)
1px * (infinity + infinity) => calc(infpx)
1px * (-infinity + -infinity) => calc(-infpx)
1px * 1/infinity => calc(0px)
1px * infinity * infinity => calc(infpx)
1px * -infinity * -infinity => calc(infpx)
```


#### Write Patch 

After writing the changes, I've tried to make clean codes. And formatting using 'git cl format'. And then I've uploaded my patch to chromium gerrit with following commit messages:


![9.png](/uploads/2020-12-23/9.png)

![10.png](/uploads/2020-12-23/10.png)

I guess this subject should be separated. So It's better to cut here.

Perhaps, Next article will be about 'code review', and change from the code review.
