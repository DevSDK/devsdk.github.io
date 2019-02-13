---
layout: post
title: Printing A + B with no limitation.
date:   2019-02-13 10:12:20
categories: algorithm
comments: true
languages:
- english
tags:
- algorithm
- solving problem
---

Today, I've started an algorithm study.

I've learned something didn't know before.

Today's problem is this:

---

### Problem
```
Write a program printing sum of A and B which are inputted.
```

### Input
```
Input values consist of multiple test-case. 
Each test-case is a single line and will be given value A and B (0 < A, B<10)
```

### Output

```
Print A + B by each test-case.
```

### Example input
```
1 1
2 3
3 4
9 8
5 2
```

### Example output
```
2
5
7
17
7
```

From [here](https://www.acmicpc.net/problem/10951).

---

So, Let's think about it.

When I met this problem, I'm just shocked. 

Honestly, I have no idea for solving this problem.

Because this problem didn't have information about the limitation of input.

So I try to find how can I solve this problem on Google and an answer sheet.

And I got Idea.

An **Eof**.

This fact makes me a little bit annoying because I can't find any information about **Eof** in that judgment site. 

So this problem's solution is this.

```c
#include <iostream>

using namespace std;
int main()
{
    int a, b;
    while(cin >> a >> b)
    {   
        cout << a + b << endl;
    }   
    return 0;
}
```

The answer has a quite funny fact.

The >> operator that was overridden return istream itself. 

That makes possible we can write like this.

```c++
	cin >> a >> b;
```
Did you find anything weird?

operator >>  have been used the condition of the while loop.

From [reference](https://en.cppreference.com/w/cpp/io/basic_ios/operator_bool), We can find the return value of overridden bool operation that is selected by an error state of  ios_base::iostate flag.

So If the state value of 'cin' is eof, we can escape from the while loop.

I didn't know istream's functions before, so this problem gave me the knowledge and it's quite happy :D.