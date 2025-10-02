---
layout: post
title: Debugging note — Filing a Chromium issue with pdf.js font bug
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
filepath: https://github.com/DevSDK/devsdk.github.io/blob/main/_i18n/en/_posts/2025-08-27-debugging-note-pdfjs-fonts.md
---

Recently, [I filed an issue](https://issues.chromium.org/u/1/issues/439716343) to crbug.com which is discovered in our frontend product. In this blog post, I'll share how I figured out it as a browser issue and how I reported it with the minimal reproduction code.

One day, our customer service team reported that some users were experiencing broken text when viewing PDFs on the Android device.

ANDROID:

![android-pdfjs-issue](/uploads/2025-08-27/android-pdfjs-issue.png)

iOS simulator:

![ios-pdfjs](/uploads/2025-08-27/ios-pdfjs.png)

*I cannot share full content of pdf. Because it is company property. For non-korean, you can find the different the characters are overwraped unexpectedly*

Our product uses  [pdf.js](https://mozilla.github.io/pdf.js/)to render pdf binary, but we re on a fairly old version. My first assumption was the version-related. Isn't it strange?  Even if it *were* true, why would the problem appear only on Android?

I started suspecting that this is a browser related-issue. But confirming that requires determining which layer is problem through multiple layers. From my experience contributing to browser project in the multiple years, having a minimal reproduction (that is, basic code of reproduction that bug) *significantly* helps pinpoint the component to investigate and fix. 


At the start of debugging, I needed to figure out which fonts were causing the problem.

I added logging to the text-rendering code in pdf.js.

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


Output e.g.,

```
canvas.js:1327 font changed:  normal normal 16px "g_d0_f2", sans-serif
canvas.js:1490 drawing  Hence,recordingandcompilingatrace
canvas.js:1327 font changed:  normal normal 16px "g_d0_f10", sans-serif
canvas.js:1490 drawing  speculates
canvas.js:1327 font changed:  normal normal 16px "g_d0_f2", sans-serif
canvas.js:1490 drawing  thatthepathand
```

I discovered that pdfjs was handling multiple font families.
It uses the Canvas API’s [context.font property](https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/font). Same as the CSS rule.


Next, I traced where the font files were being loaded.


As you can see,  the font file loaded via [document.fonts property](https://developer.mozilla.org/en-US/docs/Web/API/Document/fonts) and it allows the we can use font family as like normal way.

Now we understand how pdfjs handled the font. 

I then examined how pdfjs parses and loads fonts from the PDF binary.

* Reading the PDF binary
- Parse [CID fonts](https://en.wikipedia.org/wiki/PostScript_fonts#CID) 
    
    - CFF Parser: [https://github.com/mozilla/pdf.js/blob/master/src/core/cff_parser.js](https://github.com/mozilla/pdf.js/blob/master/src/core/cff_parser.js)
    - The results are metadata and Uint8Array font data.
	- After that as likely mentioned that, creates [FontFace](https://developer.mozilla.org/en-US/docs/Web/API/FontFace) and then put it into document.fonts
    
	    ```jsx
	      addNativeFontFace(nativeFontFace) {
	        this.nativeFontFaces.add(nativeFontFace);
	        this._document.fonts.add(nativeFontFace);
	      }
	    ```
	    
    - see: [https://github.com/mozilla/pdf.js/blob/dd560ee453c8189a9cb1ee1dea164ca1702ad020/src/display/font_loader.js#L48](https://github.com/mozilla/pdf.js/blob/dd560ee453c8189a9cb1ee1dea164ca1702ad020/src/display/font_loader.js#L48)
    - [https://developer.mozilla.org/en-US/docs/Web/API/Document/fonts](https://developer.mozilla.org/en-US/docs/Web/API/Document/fonts)





I added the following code into the parsing process to download the font blob at end.

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


Now we have the extracted .otf font file.


Using those .otf files, I created a minimal reproduction:


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


I filed the issue and shared it in the chromium slack. Someone pointed out that it was likely related to the font component or SKIA.

![slack](/uploads/2025-08-27/slack.png)

So what's next?

Now, I'm waiting for the right engineer to pick up this. If it remains unassigned for a while, probably, I plan to dig deeper into the issue itself.

---

### Updates

Dominik takes this issue! He filed an issue to [googlefonts/fontations](https://github.com/googlefonts/fontations). And suspected that started from M131.

![update](/uploads/2025-08-27/update.png)


---

### And another update!

![fixed](/uploads/2025-08-27/fixed.png)

It has been fixed at the upstream. It was a bug from the new font engine (that seems to be enabled on M131).

This fix is significant because it addresses not only the canvas issue, but also the specific font render issue on the web platform.

![font](/uploads/2025-08-27/font.png)

I can verify the issue has been resolved for the problematic pdf!

This change will be shipped in the M142 at the end of October.

![release](/uploads/2025-08-27/release.png)