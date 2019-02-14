---
layout: post
title: Printing stars with single output function. 
date:   2019-02-14 11:13:20
categories: algorithm
comments: true
languages:
- english
tags:
- algorithm
- solving problem
---

Today I've solved bit algorithm problems.

I'll write my solution one of those problems.

So Let's begin.

---

### Problem

```
Print the "*" by inferring example's rule.
```

### Input

```
Value N(1 ≤ N ≤ 100)  will be given.
```

### Output

```
Print from the first line to N line.
```

### Example Input 1

```
1
```

### Example  Output 1

```
 *
```

### Example Input 2

```
2
```

### Example Output 2
```
 *
* *
```
### Example Input 3

```
3
```
### Example Output 3
```
  *
 * *
* * *
```
### Example Input 4

```
4
```
### Example Output 4
```
   *
  * *
 * * *
* * * *
```

From [here](https://www.acmicpc.net/problem/10991)

---

Let's think about it!

It's can be solved easily if I use many **conditional expression and output expression**.

But I think It can be solved just a single output function(except newline) with loops and the ternary operator.

So Let's find the rule of this problem.

For finding the rule, I've drawn a table.

![first](/uploads/2019-02-14/1.png)

We can find some rule of this.

First, We can get the count of 'i' raw.
Second, If the N is even value, We can print '*' when the sum of 'i' and 'j' value is an odd value. If not, We can print '*' when the sum of 'i' and 'j' is even value.

The first rule can be used for a single output function(except newline). 

But the second rule makes the condition.  So We need to remove the condition.

![second](/uploads/2019-02-14/2.png)

I take 'i'+'j'-'N'.

So, '*' can be printed when that value is odd.

And,

Third, We can print ' ' when that value is less than 1.

So Let's write this to code.

```cpp
#include <iostream>

using namespace std;

int main()
{
    int N=0;

    cin>>N;

    for(int i=1; i<=N; i++)
    {   
        for(int j=1; j<=(N+i-1); j++)
            cout<< ((((i+j-N) > 0)&&(i+j-N) % 2 != 0)? "*" : " ");
        cout<<endl;
    }   
    return 0;
}
```

So this problem can be solved like this single output function(except newline).

