---
layout: post
title: \[DP\] I have solved My first DP problem. 
date:   2019-03-02 9:13:20
categories: algorithm
comments: true
languages:
- english
tags:
- algorithm
- solving problem
---

I've solved another DP problem!


---

### Problem


Peoples who live in RGB street want to paint one of three color red, green, and blue to the house. Also, they make a rule Does not paint the same color between the adjoining house. The adjoining house is i + 1 and i - 1 of the house i.

The price of painting  RED color and Green color and BLUE color will be given, then find the minimum price of painting all of the houses.

**Time limit: 0.5 Second**


### Input

The first line, N value will be given. N is less or equal to 1000. 

And the painting price of red, green, and blue color will be given after the first line.


### Output

Print the minimum price of painting color.

### Example Input 

```
3
26 40 83
49 60 57
13 89 99
```

### Example  Output 

```
96
```

From [here](https://www.acmicpc.net/problem/1149)

---


When I read this problem the first time, I didn't know how do I solve using DP this problem.

Even I have no idea how do I solve this using full-search.

The very first time, I just think I can use DP with an array which is 6 sized and contain the value of case select Red, Green, and Blue and before selected color. And I try to solve with iterate statement.

But that solution makes the wrong output.

So I try to come back to the full-search method with a recursive function. 

Let's think about it.

It always makes two selection number of the case except for the first line.

Because We have adjoining houses painting rule.


So We need to calculate like this:

![first](/uploads/2019-03-02/1.png)

The blue dotted line is the solution path (It is just one of the path to calculate the price).


We can make this to function at reverse order for define recursive function.


Let's define the function returns min value of price at N and color.

And we can find the price is always the same at N and color.

That is DP. we can use DP.

So when function at N and color is already calculated, we can return the calculated value.

Let's write the 'select' function which selects the minimum value of two cases.

```cpp

int select(int n, int i)
{

    if(dp[n][i] != 0)
        return dp[n][i];
    
    if(n==0)
    {
        return input[0][i];
    }
    int res = min(input[n][i] + select(n-1, (i+1)%3), input[n][i] + select(n-1,(i+2)%3));
    dp[n][i]=res;
    return res;
}

```
i is color, n is house number.

Let's call this function case 0, 1, and 2.

So The final source code is:

```cpp
#include <iostream>

using namespace std;

int input[1000][3];

int dp[1000][3];



int select(int n, int i)
{

    if(dp[n][i] != 0)
        return dp[n][i];
    
    if(n==0)
    {
        return input[0][i];
    }
    int res = min(input[n][i] + select(n-1, (i+1)%3), input[n][i] + select(n-1,(i+2)%3));
    dp[n][i]=res;
    return res;
}

int select_all(int n)
{
    return min(select(n,0), min(select(n,1),select(n,2)));
}

int main()
{
    int N;
    cin>>N;

    for(int i=0;i<N;i++)
    {
        cin>>input[i][0];
        cin>>input[i][1];
        cin>>input[i][2];
    }
    cout<<select_all(N-1)<<endl;    
    
    return 0;
}
```

Sorry for the unreadable article.

Because I'm burned and hungry!

