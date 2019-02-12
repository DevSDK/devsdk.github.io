---
layout: post
title: NaverWordBookExtractor 개발기
date:   2018-02-18 22:46:20		
categories: development
comments: true
languages:
- english
- korean
tags:
- Naver
- Web
- Parsing
- python
---		

엄청 오랬만에 블로그에 글을 쓰는 듯 하다.

일단 0SOS의 개발은 일시 중단되어있다.

나중에 글을 전부 영어로 작성하게 된다면 그때 다시 시작할까 한다.

그런 의미로 잘 쓰고있는 Naver 단어장에서의 퀴즈 기능의 부족함을 느껴

아는 사람의 추천으로 알게된 quizlet 이란 홈페이지를 이용하고자 했다.

[QuizLet](https://quizlet.com)

quizlet을 사용해 본 사람은 알겠지만 데이터를 스프레드시트나 raw text로 단어-뜻 쌍을 집어넣게 되어있다.

하지만 네이버 단어장은 단어들을 파일이나 순수 텍스트로 추출할 수 있는 기능을 전혀 제공하고 있지 않았고  단어장에 저장되어 있는 많은 단어들을 일일히 손으로 옮기기엔 너무 시간이 낭비될 것 같았다. 

따라서 간단하게 네이버 단어장 단어 추출 프로그램을 만들어서 사용하기로 했고 간단하면서도 Multiplatform 에 특화되어있는 Python을 이용해 개발하기로 했다.

일단 네이버 자체에서 단어장이나 단어사전쪽에선 손을 놓은건지, 준비중인건진 모르겠지만 API가 전혀 제공되지 않았다.

그렇기 때문에 직접 html 파싱을 통해 데이터를 추출해야 하는데 네이버 단어장은 계정 로그인이 되어있어야 그 계정의 단어장에 엑세스 할 수 있기 때문에 네이버에 로그인을 해야 한다는 문제와 마주치게 된다.

처음엔 selenium을 사용할까도 했으나 별도의 WebDriver 존제가 가볍게 사용하기엔 부적합 할 것 같다는 판단을 하게 되어 selenium 사용은 미루었다.

따라서 네이버 로그인 기능을 웹브라우져에서 처리하는 것 과 같이 해주어야 한다. 

따라서 [로그인 페이지](https://nid.naver.com/nidlogin.login) 를 분석해 보기로 한다.

 ![네이버 로그인 페이지 분석](/uploads/2018-02-18/NaverSignIn.png)

 크롬 개발자 도구를 이용해 로그인 버튼이 눌렸을때의 동작을 살펴보면.


 ```html
<form id="frmNIDLogin" name="frmNIDLogin" target="_top" autocomplete="off" action="https://nid.naver.com/nidlogin.login" method="post" onsubmit="return confirmSubmit();">

        <input type="hidden" name="enctp" id="enctp" value="1">
        <input type="hidden" name="encpw" id="encpw" value="">
        <input type="hidden" name="encnm" id="encnm" value="">
        <input type="hidden" name="svctype" id="svctype" value="0">
        <input type="hidden" name="svc" id="svc" value="">
        <!-- 블라블라블라 기타 코드 생략 -->

        <input type="submit" title="로그인" alt="로그인" tabindex="12" value="로그인" class="btn_global" onclick="nclks('log.login',this,event)">

        <!-- 블라블라블라 기타 코드 생략 -->
</form>

 ```

 보면 submit (로그인) 버튼이 눌렸을때 confirmSubmit 함수를 호출하게 되어있고 post로 enctp, encpw 등과같은 다양한 키로 데이터가 보내진다고 보인다.

confirmSubmit 함수가 호출된다는 정보를 알았으니 이제 네이버에서 가져오는 js 파일들에서 해당 함수를 찾아보았다.

![find_function](/uploads/2018-02-18/confirmSubmit_func.png)

어렵지 않게 함수를 찾을 수 있었다.

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

해당 함수이다.
보면 대충 아이디 비번 안치면 경고띄워주는 로직이 보인다. 그게 중요한게 아니라
딱봐도 수상해보이는 함수가 보인다. encryptIdPw 함수를 호출한다는 단서를 얻었으니 해당 함수를 찾아서 때보면

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

이 함수를 보아 로그인 시 아이디와 비밀번호를 rsa 암호화로 암호화 한 다음 로그인 url ("https://nid.naver.com/nidlogin.login")에다가 post 요청을 하며 encpw에다가 암호문을 실어 보내는 것 같다.

일단 저 일련의 과정을 처리하기 위해선 알아야 할 것이 session_keys와 keySplit 그리고 getLenChar 함수로 보인다. 
getLenChar 함수는 원형이 다음과 같다.

```javascript
function getLenChar(a) {
    a = a + "";
    return String.fromCharCode(a.length)
}
```

단순히 문자열의 길이를 ascii code로 변환해 주는 함수이다. 

그리고 session_keys keySplit 함수를 찾아보면 

session_keys는 결론부터 말하자면 "https://nid.naver.com/login/ext/keys.nhn" 에서 가져오는 공개키 생성용 값 (e,n)과 기타등등을 ","를 구분자로 구분해 가져오게 된다.

session_keys의 set 과정을 역 추적해보면 유저가 pw 텍스트박스에 텍스트를 입력했을때 getKeysv2함수를 호출하고 해당함수에서 ajax로 호출해서 설정하게 된다.

예시 (임의의 값이므로 이 값은 동작하지 않음, 보기좋게 개행을 추가했다.)
```
gs0TbOWaCaYxTQ0,
102042940,
ad1ca063118c32asdd51a8c53119faa8bc9c8cb0f743d8f1b89db53cc8f4647784ab08b0f4704e2a49c85cdf44e1830c04ad3505cb977810768a3cwrrq8ce38d2956892722f45aecc6bfc23248e2fe453a4d20b51344968b8ffa848068d72d05e5aa679fbaef4351e099aea00fd6fccfff598426b0d12bdc660e601dd7a93bbd,
010001
```
이제 마지막 KeySplit 함수를 살펴보면 

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

간단한 함수이다. 이제 필요한 정보는 모두 얻었다.

다시한번 간단하게 말하자면 post로 보낼 encpw값에
 getLenChar(sessionkey) + sessionkey +	getLenChar(id.value) + id.value + getLenChar(pw.value) + pw.value);이 문자열을 받아온 e와 n 값으로 RSA 공개키 암호화 하여 보내면 무엇인가 일어난다 인 것이다.

 파이썬으로 간단하게 작성을 해보았다.

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
여기서 고의인지 실수인진 모르겠으나 session_keys 에서 parsing 해오는 값인 evalue와 nvalue는 반대로 되어있다. 자꾸 Rsa Encrypt 쪽에서 앱이 죽어서 살펴보니 n과 e가 반대로 들어와있었다. 즉, javascript에 있는 evalue는 사실 n 이고 nvalue는 사실 e 다. 이럴수가. 내생각엔 네이버 개발자가 실수 한 것 같다. 

아무튼 네이버 로그인 페이지에서 하는 동작과 동일하게 동작한다.
만약 info 딕셔너리의 아이디와 비밀번호가 정확하다면 

```html
<html>
<script language=javascript>
location.replace("https://nid.naver.com/login/sso/finalize.nhn?url=http%3A%2F%2Fwww.naver.com&sid=rbCj4sWaqQfCweR&svctype=1");
</script>
</html>
```
이런식으로 리다이렉션 URL이 날아온다.
저 URL을 (직접 생성한, 위 예시는 임의로 만든 URL이다.) 타고 가면 로그인이 완료되는데, 리다이렉션 3번을 거친다.
이로써 로그인을 완료했다. 

완전 깔끔하게 만들곤 싶었으나, 네이버에서 로그인 실패가 5번을 넘어가면 켑챠가 동작하여 로그인 기능이 먹통이 되는데, 여기에 딥러닝같은 걸 사용하기도 그렇고. 그럴땐 그냥 웹브라우져로 (크롬은 시크릿모드) 로그인을 시도해 캡챠를 통과해주면 되는 것 같다.

데이터를 불러와서 파일에 쓰는것 까지는 무난하게 beautifulsoup 4 를 이용해 파싱해 사용한다.

아래 링크는 현제까지 작성된 source code이며, 개선의 여지가 많이 보이나 시간을 많이 투자하진 않고 있다.

[SourceCode](https://github.com/DevSDK/NaverWordBookExtractor/blob/master/NaverWordBookExtractor.py)

밤새고 의식의 흐름대로 쓴 글이라 정리를 제대로 못한 느낌이 없잖아 있다.

