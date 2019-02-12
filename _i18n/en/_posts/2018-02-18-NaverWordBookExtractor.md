---
layout: post
title: Dev log of NaverWordBookExtractor
date:   2018-02-18 22:46:20        
categories: development
languages:
- english
- korean
tags:
- Naver
- Web
- Parsing
- python
---        

Wow, It's quite loooong time to write this article in here.

As you know 0SOS development was paused.

When I finish translating blog posting, Maybe I'll resume.

I felt Naver vocabulary doesn't have enough function. So I try to use Quizlet that was introduced by my friend. 

[QuizLet](https://quizlet.com)

A person who used the quizlet know about it. When I try to add words in the quizlet, I need to excel file pair of word-mean raw text. 

But Naver vocabulary doesn't have any extract function and if I write my hand, it would use a lot of time.

So I decide to develop a word-extract program. I chose python because that is simple and multiplatform.

First, Naver didn't support any API.

So I should parse from html. The problem is Program need to sign-in to Naver account to access my vocabulary. 

At the begin of developing, I thought using selenium, but I considered WebDriver makes this heavy. So selenium wasn't proper. 

So We need to make sign-in in steps like the web browser.  

So Let's analyze [sign-in page](https://nid.naver.com/nidlogin.login) 

![Analysis of Naver Sign-in page](/uploads/2018-02-18/NaverSignIn.png)

Let's see what happen when we press the sign-in button using chrome development tools.

 ```html
<form id="frmNIDLogin" name="frmNIDLogin" target="_top" autocomplete="off" action="https://nid.naver.com/nidlogin.login" method="post" onsubmit="return confirmSubmit();">

        <input type="hidden" name="enctp" id="enctp" value="1">
        <input type="hidden" name="encpw" id="encpw" value="">
        <input type="hidden" name="encnm" id="encnm" value="">
        <input type="hidden" name="svctype" id="svctype" value="0">
        <input type="hidden" name="svc" id="svc" value="">
        <!-- Skip etc codes -->

        <input type="submit" title="로그인" alt="로그인" tabindex="12" value="로그인" class="btn_global" onclick="nclks('log.login',this,event)">

        <!--  Skip etc codes -->
</form>

 ```

You can see the confirmSubmit function is called when I press submit button and data will send by these keys like 'enctp', 'encpw' using the POST method.  

Let's read the content of the confirmSubmit function in the js file.

![find_function](/uploads/2018-02-18/confirmSubmit_func.png)

```javascript
function confirmSubmit() {
    var id = $("id");
    var pw = $("pw");
    var encpw = $("encpw");
    
    //if(id.value == "" && encpw.value == "") {
    if(id.value == "") {
        show("err_empty_id");
        hide("err_empty_pw");
        hide("err_common");
        id.focus();
        return false;
    //} else if(pw.value == "" && encpw.value == "") {
    } else if(pw.value == "") {
        hide("err_empty_id");
        show("err_empty_pw");
        hide("err_common");
        pw.focus();
        return false;
    }
    try{
        $("ls").value = localStorage.getItem("nid_t");
    }catch(e){}

    return encryptIdPw();
}
```

It is the confirmSubmit function.

We can see id and password empty notification warning logic. But that isn't an important thing.

As you can see a function that looks important has existed there.

Let's see this.

```javascript
function encryptIdPw() {
    var id = $("id");
    var pw = $("pw");
    var encpw = $("encpw");
    var rsa = new RSAKey;

    if (keySplit(session_keys)) {
        rsa.setPublic(evalue, nvalue);
        try{
            encpw.value = rsa.encrypt(
                getLenChar(sessionkey) + sessionkey +
                getLenChar(id.value) + id.value +
                getLenChar(pw.value) + pw.value);
        } catch(e) {
            return false;
        }
        $('enctp').value = 1;
        id.value = "";
        pw.value = "";
        return true;
    }
    else
    {
        getKeyByRuntimeInclude();
        return false;
    }

```

I can find this function makes request sending encrypted RSA data from ID and Password to login url("https://nid.naver.com/nidlogin.login") using post 'encpw' key.

We should know the session_keys, keySplit, and getLenChar functions.

Let's see them.

```javascript
function getLenChar(a) {
    a = a + "";
    return String.fromCharCode(a.length)
}
```

that function return length of the parameter string.

Let's see session_keys and keySplit.

session_keys return requirement value(e,n) and etc for public-key generation from "https://nid.naver.com/login/ext/keys.nhn".

Let's get inside of seesion_key's set step.

When the user writes text in pw textbox, getKeysv2 function will be called using ajax so we can take key values. 


Example (This isn't proper value. So This key wouldn't work. I add new-line for reading)
```
gs0TbOWaCaYxTQ0,
102042940,
ad1ca063118c32asdd51a8c53119faa8bc9c8cb0f743d8f1b89db53cc8f4647784ab08b0f4704e2a49c85cdf44e1830c04ad3505cb977810768a3cwrrq8ce38d2956892722f45aecc6bfc23248e2fe453a4d20b51344968b8ffa848068d72d05e5aa679fbaef4351e099aea00fd6fccfff598426b0d12bdc660e601dd7a93bbd,
010001
```

Let's see keySplit function.

```javascript
function keySplit(a) {
    keys = a.split(",");
    if (!a || !keys[0] || !keys[1] || !keys[2] || !keys[3]) {
        return false;
    }
    sessionkey = keys[0];
    keyname = keys[1];
    evalue = keys[2];
    nvalue = keys[3];
    $("encnm").value = keyname;
    return true
}
```

It's a simple function. Okay, we have information for implementing this.

Simply, It's make 'encpw' key value using ' getLenChar(sessionkey) + sessionkey +    getLenChar(id.value) + id.value + getLenChar(pw.value) + pw.value)' for sending post.

So When this string encrypts using RSA with e and n value, it ganna make a something happen. 

I write the script using python.

```python
from bs4 import BeautifulSoup 
import requests
import rsa
from rsa import common, transform, core
import re

info = { "id" : "", "pw" : "" }
session = requests.Session()
session_key_string = ""
session_keys = {}
def split_keys(a):
    keys = a.split(',')
    if (a is None or keys[0] is None or keys[1] is None or keys[2] is None or keys[3] is None):
        return False
    session_keys["sessionkey"] = keys[0]
    session_keys["keyname"] = keys[1]
    session_keys["evalue"] = keys[2]
    session_keys["nvalue"] = keys[3]
    return True

def getLenChar(a):
    return chr(len(a))    

def encrypt():
    id = info['id']
    pw = info['pw']
    pub_key = rsa.PublicKey(e=int(session_keys["nvalue"],16), n = int(session_keys["evalue"],16))
    source  = (getLenChar(session_keys["sessionkey"]) + session_keys["sessionkey"] + getLenChar(info["id"]) + info["id"]
            + getLenChar(info["pw"]) + info["pw"])
    return rsa.encrypt(source.encode('utf-8'), pub_key)

def signin():
    session_key_string = requests.get("https://nid.naver.com/login/ext/keys.nhn").text
    if(split_keys(session_key_string) is False):
        print("Error")
        return False
    encrypted_source = encrypt()
    postdata = {
    "encpw": encrypted_source.hex(), 
    "enctp": 1,
    "encnm": session_keys["keyname"],
    }
    response = session.post("https://nid.naver.com/nidlogin.login", data=postdata)
    if response.text.count('\n') > 50 :
        print("sigin in error")
        return False
        
    print(response.text)
    return True
    
if signin() is False:
    exit(0)
```
I find something weird thing. 

It is swapped between evalue and nvalue parsing data from session_keys.

I don't know this is a mistake or design.

Anyway, I found this problem, because application keep dying on Rsa Encrypt step and I found n and e value swapped.

That mean e value is n and n value is e in javascript.

Whatever, It worked properly like Naver sign-in step.

If info dictionary id and password is correct,

```html
<html>
<script language=javascript>
location.replace("https://nid.naver.com/login/sso/finalize.nhn?url=http%3A%2F%2Fwww.naver.com&sid=rbCj4sWaqQfCweR&svctype=1");
</script>
</html>
```
It will return redirection URL.

After three steps of redirect, it's done. Now the program is signed-in.

I wanna more clearly, but it has a captcha and it makes blocks login. 

But Maybe I use like deep-learning is over-engineering. 

So I think if it happens, just sign-in on the web browser for passing the captcha.

I use 'beautifulsoup 4' for parsing. 

Below url is source code. 

[SourceCode](https://github.com/DevSDK/NaverWordBookExtractor/blob/master/NaverWordBookExtractor.py)

IDK this article is quite readable. Because I didn't sleep.