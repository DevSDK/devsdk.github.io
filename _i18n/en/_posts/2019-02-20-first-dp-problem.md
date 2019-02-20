---
layout: post
title: \[DP\] I have solved My first DP problem. 
date:   2019-02-20 9:13:20
categories: algorithm
comments: true
languages:
- english
tags:
- algorithm
- solving problem
---

Now, I solved a DP problem.

```
Dynamic programming is one of the problem-solving methods.  this method divides a problem to sub-problems. It stores a result of the algorithm by specific values to the memory for reusing. So When that value occurs, We can use that data again. Thus we can optimize re-computing time.
```

---

### Problem

```
Following source code is C++ function for calculating N
Fibonacci number.
```

```c++
int fibonacci(int n) {
    if (n == 0) {
        printf("0");
        return 0;
    } else if (n == 1) {
        printf("1");
        return 1;
    } else {
        return fibonacci(n‐1) + fibonacci(n‐2);
    }
}
```

When fibonacci(3) is called, it would be worked like this:
	
* fibonacci(3)  call fibonacci(2) and fibonacci(1)(first called).
* fibonacci(2) call fibonacci(1)(second called) and fibonacci(0).
* fibonacci(1)(second called) return and print 1.
* fibonacci(0) return and print 0.
* fibonacci(2) get result of fibonacci(1) and fibonacci(0) and return 1.
* fibonacci(1)(fist called) return and print 1.
* fibonacci(3) get result of fibonacci(2) and fibonacci(1) and return 2.

Thus, number 1 printed the twice and 0 printed a single.

Write a program to calculate how many number 0 and 1 printed when number N is given.

**Time limit: 0.25 Second**


### Input

```
The value T will be given that is the count of test-case.
Each case consists of a single line which is number N.
(0<=N<=40)
```

### Output

```
Print the numbers of the count of 0 and 1 which is separated by the white-space.
```

### Example Input 

```
3
0
1
3
```

### Example  Output 

```
1 0
0 1
1 2
```

From [here](https://www.acmicpc.net/problem/1003)

---

When I met this problem the first time, I just used counting 0 and 1.

But my counting method always made the time-over.

I had some few times for thinking. The main topic is calculation time.

And the following idea occurred to me.

**If I store the value of fibonacci(N) to reuse?**

If I do that, This algorithm makes calculation just a single time by the N value.

So I fixed above function like this.

```c++
int DP[41] = {0};

int fibonacci(int n) {
    if (n == 0) {
        return 0;
    } else if (n == 1) {
        return 1;
    } else {
        if(DP[n]!=0)
            return DP[n];
        else
        {
            int res = fibonacci(n-1) + fibonacci(n-2);
            DP[n] = res;
            return res;
        }
    }   
}
```

If fibonacci(2) called the first time, it would call fibonacci(1) and fibonacci(0) functions which just return 1 and 0. 
And then it stored the result of fibbonacci(2) to DP[2].

Thus, when fibonacci function called next time, it would return the value of DP[2].

So It's solved!

But let's see the problem.

We need to count how many 0 and 1 is printed.

But we can't count use counter because every function by N is called a single time. 

Let's think.

We need to find how many N value consists of 1 and 0 makes function-call.

Let's think when fibonacci(2) is called.

fibonacci(2) makes fibonacci(1) and fibonacci(0).

As you can see that makes counting each 1 and 0 by specific value N=2.

Thus, We can make this formula:

zero_count = { 1, 0, 0 ...}
zero_count[N] = zero_count[N-1] + zero_count[N-2] 

one_count { 0, 1, 0 ...}
one_count[N] = one_count[N-1] + one_count[N-2]

So If I use above to source code, we can solve finally.

```c++
#include <iostream>
using namespace std;

int DP[41] = {0};
int DPC[41] = {0,1,0,};
int DPZC[41] = {1,0,};
int fibonacci(int n) {
    if (n == 0) {
        return 0;
    } else if (n == 1) {
        return 1;
    } else {
        if(DP[n]!=0)
            return DP[n];
        else
        {
            int res = fibonacci(n-1) + fibonacci(n-2);
    
            DPC[n] = DPC[n-1] + DPC[n-2];   
            DPZC[n] = DPZC[n-1] + DPZC[n-2];

            DP[n] = res;
            return res;
        }
    }   
}

int main()
{
    int T,N;
    cin.sync_with_stdio(false);
    cout.sync_with_stdio(false);
    cin.tie(nullptr);
    cout.tie(nullptr);
    cin>>T;
    for(int i=0;i<T;i++)
    {   
        cin>>N;
        fibonacci(N);
        cout<<DPZC[N]<<" "<<DPC[N]<<'\n';
    }   
    return 0;
}
```

I heard DP method but I couldn't use that.

And luckily I can deploy that method through this problem!
