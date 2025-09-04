---
layout: post
title: 디버깅 노트 — pdf.js 폰트 버그로 Chromium 이슈 등록하기
date:   2025-08-27 9:00:00+0900
categories: development
comments: true
languages:
- english
- korean
tags:
- Chromium
- Frontend
- pdf
---

최근에 회사 프론트엔드 제품에서 발견한 이슈를 chromium 이슈 트레커 crbug에 제보했다. 이 블로그 포스트에서는 브라우저 이슈라고 파악한 과정과 최소한의 재현 코드로 리포트한 방법을 간략히 공유하려고 한다.

issue: [https://issues.chromium.org/u/1/issues/439716343](https://issues.chromium.org/u/1/issues/439716343)


얼마 전 CS팀에서 일부 사용자들이 Android 기기에서 PDF를 볼 때 텍스트가 깨진다고 공유했다.

ANDROID:

![android-pdfjs-issue](/uploads/2025-08-27/android-pdfjs-issue.png)

iOS 시뮬레이터:

![ios-pdfjs](/uploads/2025-08-27/ios-pdfjs.png)

*PDF의 전체 내용은 공유할 수 없다.*

우리 제품은 [pdf.js](https://mozilla.github.io/pdf.js/)를 사용해서 PDF 바이너리를 렌더링하는데, 꽤 오래된 버전을 사용하고 있다. 처음에는 버전 관련 문제라 생각했다. 설령 버전 문제가 *맞다고* 한다고 하더라도, 왜 Android에서만 문제가 나타날까?

안드로이드에서만 발생하는 현상으로 이 문제는 브라우저 관련 이슈라고 의심하기 시작했다. 하지만 이를 확인하려면 여러 레이어를 거쳐 어느 레이어에서 문제가 발생하는지 파악해야 한다. 지난 몇 년간 브라우저 프로젝트에 기여한 경험상, 최소한의 재현 코드(즉, 버그를 재현하는 기본 코드)가 있으면 조사하고 수정할 컴포넌트를 찾는 데 *상당히* 도움이 된다.

디버깅을 시작할 때, 어떤 폰트가 문제를 일으키는지 파악해야 했다.

pdf.js의 텍스트 렌더링 코드에 로깅을 추가했다.

```diff
+
      if (!fontObj) {
        throw new Error(`Can't find font for ${fontRefName}`);
      }
@@ -1321,6 +1323,8 @@ var CanvasGraphics = (function CanvasGraphicsClosure() {

      var rule = italic + ' ' + bold + ' ' + browserFontSize + 'px ' + typeface;
      this.ctx.font = rule;
+
+      console.log('font changed: ', rule);
    },
    setTextRenderingMode: function CanvasGraphics_setTextRenderingMode(mode) {
      this.current.textRenderingMode = mode;
@@ -1483,6 +1487,7 @@ var CanvasGraphics = (function CanvasGraphicsClosure() {
      ctx.lineWidth = lineWidth;

      var x = 0, i;
+      console.log('drawing ',glyphs.map(g=>g.fontChar).join(''));
      for (i = 0; i < glyphsLength; ++i) {
        var glyph = glyphs[i];
```

출력 예시:

```
canvas.js:1327 font changed:  normal normal 16px "g_d0_f2", sans-serif
canvas.js:1490 drawing  Hence,recordingandcompilingatrace
canvas.js:1327 font changed:  normal normal 16px "g_d0_f10", sans-serif
canvas.js:1490 drawing  speculates
canvas.js:1327 font changed:  normal normal 16px "g_d0_f2", sans-serif
canvas.js:1490 drawing  thatthepathand
```

pdfjs가 여러 폰트 패밀리를 처리하고 있다는 것을 발견했다.
Canvas API의 [context.font property](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/font)를 사용한다. CSS 규칙과 동일하다.

다음으로, 폰트 파일이 어디서 로드되는지 추적했다.

보다시피, 폰트 파일은 [document.fonts property](https://developer.mozilla.org/en-US/docs/Web/API/Document/fonts)를 통해 로드되며, 이를 통해 일반적인 방식으로 폰트 패밀리를 사용할 수 있다.

이제 pdfjs가 폰트를 어떻게 처리하는지 알게 되었다.

그 다음 pdfjs가 PDF 바이너리에서 폰트를 파싱하고 로드하는 방식을 살펴봤다.

* PDF 바이너리 읽기
- [CID fonts](https://en.wikipedia.org/wiki/PostScript_fonts#CID) 파싱 
    
    - CFF Parser: [https://github.com/mozilla/pdf.js/blob/master/src/core/cff_parser.js](https://github.com/mozilla/pdf.js/blob/master/src/core/cff_parser.js)
    - 결과는 메타데이터와 Uint8Array 폰트 데이터다.
	- 그 다음 앞서 언급한 대로 [FontFace](https://developer.mozilla.org/en-US/docs/Web/API/FontFace)를 생성하고 document.fonts에 추가한다
    
	    ```jsx
	      addNativeFontFace(nativeFontFace) {
	        this.nativeFontFaces.add(nativeFontFace);
	        this._document.fonts.add(nativeFontFace);
	      }
	    ```
	    
    - 참고: [https://github.com/mozilla/pdf.js/blob/dd560ee453c8189a9cb1ee1dea164ca1702ad020/src/display/font_loader.js#L48](https://github.com/mozilla/pdf.js/blob/dd560ee453c8189a9cb1ee1dea164ca1702ad020/src/display/font_loader.js#L48)
    - [https://developer.mozilla.org/en-US/docs/Web/API/Document/fonts](https://developer.mozilla.org/en-US/docs/Web/API/Document/fonts)

파싱 과정을 아래 코드를 집어넣어 마지막에 폰트 blob을 다운로드하도록 했다.


```js
function detectFontType(u8) {
  const h0 = u8[0], h1 = u8[1], h2 = u8[2], h3 = u8[3];
  const sig = String.fromCharCode(h0, h1, h2, h3);
  if (sig === 'wOFF') return { mime: 'font/woff',  ext: '.woff'  };
  if (sig === 'wOF2') return { mime: 'font/woff2', ext: '.woff2' };
  if (sig === 'OTTO') return { mime: 'font/otf',   ext: '.otf'   }; // OpenType/CFF
  if (h0 === 0x00 && h1 === 0x01 && h2 === 0x00 && h3 === 0x00) {
    return { mime: 'font/ttf', ext: '.ttf' }; // TrueType/OpenType
  }

  return { mime: 'application/octet-stream', ext: '.bin' };
}


function downloadBlob(u8, filename = 'font') {
  const { mime, ext } = detectFontType(u8);
  const blob = new Blob([u8], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = Object.assign(document.createElement('a'), {
    href: url, download: filename.endsWith(ext) ? filename : filename + ext
  });
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
} 

if(nativeFontFace.family === 'g_d1_f5') {
   downloadBlob(this.data);
 }
```

이제 추출된 .otf 폰트 파일을 얻었다.

이 .otf 파일들을 사용해서 최소한의 재현 코드를 만들었다:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Canvas Font Test</title>
    <style>
        body {
            margin: 20px;
            font-family: system-ui, -apple-system, sans-serif;
        }
        .canvas-container {
            margin-bottom: 30px;
        }
        canvas {
            border: 1px solid #ccc;
            margin-top: 10px;
        }
        h2 {
            margin: 10px 0;
            color: #333;
        }
    </style>
</head>
<body>
    <h1>Canvas Font Test</h1>

    <div class="canvas-container">
        <h2>g_d1_f16.otf</h2>
        <canvas id="canvas_f16" width="800" height="200"></canvas>
    </div>

    <div class="canvas-container">
        <h2>g_d1_f5.otf</h2>
        <canvas id="canvas_f5" width="800" height="200"></canvas>
    </div>

    <div class="canvas-container">
        <h2>g_d1_f6.otf</h2>
        <canvas id="canvas_f6" width="800" height="200"></canvas>
    </div>

    <div class="canvas-container">
        <h2>g_d1_f7.otf</h2>
        <canvas id="canvas_f7" width="800" height="200"></canvas>
    </div>

    <script>
    (async () => {
        // Font configurations
        const fontConfigs = [
            { name: 'G_D1_F16', file: 'g_d1_f16.otf', canvasId: 'canvas_f16' },
            { name: 'G_D1_F5', file: 'g_d1_f5.otf', canvasId: 'canvas_f5' },
            { name: 'G_D1_F6', file: 'g_d1_f6.otf', canvasId: 'canvas_f6' },
            { name: 'G_D1_F7', file: 'g_d1_f7.otf', canvasId: 'canvas_f7' }
        ];

        // Load all fonts
        const fontPromises = fontConfigs.map(config => {
            const font = new FontFace(config.name, `url('./${config.file}')`);
            return font.load().then(loadedFont => {
                document.fonts.add(loadedFont);
                return { ...config, loadedFont };
            }).catch(err => {
                console.error(`Failed to load font ${config.file}:`, err);
                return { ...config, error: err };
            });
        });

        const loadedFonts = await Promise.all(fontPromises);

        loadedFonts.forEach(config => {
            const canvas = document.getElementById(config.canvasId);
            const ctx = canvas.getContext('2d');

            ctx.fillStyle = 'white';
            ctx.fillRect(0, 0, canvas.width, canvas.height);

            if (config.error) {
                ctx.fillStyle = 'red';
                ctx.font = '16px sans-serif';
                ctx.fillText(`Error loading font: ${config.file}`, 10, 30);
                return;
            }

            ctx.fillStyle = 'black';
            
            ctx.font = '32px ' + config.name;
            ctx.fillText('The quick brown fox - ABC123', 20, 50);

            ctx.font = '32px ' + config.name;
            ctx.fillText('다람쥐 헌 쳇바퀴에 타고파', 20, 100);

            ctx.font = '32px ' + config.name;
            ctx.fillText('1234567890 !@#$%^&*()', 20, 150);

            ctx.font = '12px sans-serif';
            ctx.fillStyle = '#666';
            ctx.fillText(`Font: ${config.file}`, canvas.width - 200, canvas.height - 10);
        });
    })();
    </script>
</body>
</html>
```

![reproduction](/uploads/2025-08-27/reproduction.png)

이슈를 제보하고 chromium slack에 공유했다. 누군가가 이것이 폰트 컴포넌트나 SKIA와 관련이 있을 것 같다고 말해줬다.

![slack](/uploads/2025-08-27/slack.png)

그럼 다음은?

지금은 적절한 엔지니어가 이 이슈를 담당하기를 기다리고 있다. 만약 한동안 할당되지 않는다면, 아마도 이 이슈 자체를 직접 더 깊이 파볼 계획이다.

---

### 업데이트!

Dominik 이 이슈를 가져갔다! googlefonts/fontations 에 이슈를 올렸다고 한다. M131 부터 발생한거로 추정된다고 한다.

![update](/uploads/2025-08-27/update.png)

---

### 그리고 또 다른 업데이트!

![fixed](/uploads/2025-08-27/fixed.png)

업스트림에서 문제가 수정되었다. 새로운 폰트 엔진(아마 M131에서 활성화된 것으로 보인다)에서 나온 버그였다.

이번 수정은 캔버스 이슈뿐만 아니라 웹 플랫폼에서의 특정 폰트 렌더링 문제도 함께 해결한다는 점에서 의미가 크다.

![font](/uploads/2025-08-27/font.png)

문제가 있었던 PDF에서 이슈가 해결된 것을 확인했고, 10월 말에 릴리즈되는 M142에 포함되어 배포될 예정이다.

![release](/uploads/2025-08-27/release.png)