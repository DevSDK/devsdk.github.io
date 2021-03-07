---
layout: post
title: html webpack plugin URL undefined 이슈	
date:   2021-02-17 20:02:20		
categories: development
comments: true
languages:
- korean
tags:
- Webpack
- html
- Web
---		

짧은 포스팅

WebPack에는 html-webpack-plugin 이라는 플러그인이 있다.

HTML을 불러와서 컴파일 한 녀석에 붙여주는 역할을 한다. 링커랑 비슷한 것 같기도 하다.

DFD의 favicon을 추가하는 작업을 하다가 계속 이 에러메시지를 보았다.

&lt;link rel="icon" type="image/x-icon" href="static/favicon.ico" /&gt; 이 태그가 들어가면,

정확히는 href가 포함된 태그가 들어가면 아래와 같은 메시지를 내보내며 컴파일 에러를 띄운다.

```
ERROR in   Error: /home/seokho/projects/DFD-WEB/public/index.html:147
  var ___HTML_LOADER_IMPORT_0___ = new URL(/* asset import */ __webpack_require__(/*! ./static/favicon.ico */ "./public/static/favicon.ico"), __webpack_require__.b);
                                   ^
  ReferenceError: URL is not defined
  
  - index.html:147 
    /home/seokho/projects/DFD-WEB/public/index.html:147:34
  
  - index.html:153 
    /home/seokho/projects/DFD-WEB/public/index.html:153:3
  
  - index.html:156 
    /home/seokho/projects/DFD-WEB/public/index.html:156:12
  
  - index.js:136 HtmlWebpackPlugin.evaluateCompilationResult
    [DFD-WEB]/[html-webpack-plugin]/index.js:136:28
  
  - index.js:333 
    [DFD-WEB]/[html-webpack-plugin]/index.js:333:26
  
  - async Promise.all
  
  - async Promise.all
```

왜 그런 것이지 하고 검색을 해도 방법이 잘 나오지 않았다.

의심한 건 가장 첫 번째로 노드 버전이다.

아니나 다를까 버전이 아주 낮았다. 업데이트해도 해결이 되지 않았다.

그래서 HtmlWebpackPlugin 이쪽 코드를 한번 보자고 깃헙에 들어가서 소스를 읽고 이슈리스트를 보았다.

아니나 다를까, 3일 전에 2.0으로 업데이트된 html-loader 라는 녀석에서 발생하는 이슈였다.

[https://github.com/jantimon/html-webpack-plugin/issues/1602](https://github.com/jantimon/html-webpack-plugin/issues/1602)

이슈가 해결되는 패치가 등장하기 전까진, 

html-loader 버전을 2.0에서 1.3.2 으로 다운그레이드 하는것으로 해결
