---
layout: post
title: V8 debugging note
date:   2025-03-16 16:00:00+0900
categories: development
comments: true
languages:
- english
tags:
- Chromium
- V8
- Debugging
---

This post simply contains a debugging note for V8 development for myself.
Please let me know if you know a more efficient way.

This post will be updated I got something useful.


# TOOLS

https://v8.github.io/tools/head/

# CSA

## Print
### Handle\<T\>

To Print `Handle<T>` in CSA, we can use `HeapConstantNoHole`

```cpp

  Handle<String> name = DoSomething(); 
  auto temp = HeapConstantNoHole(name);
  Print(temp);
```

```
DebugPrint: 0x4ca00004859: [String] in ReadOnlySpace: #global
0x4ca00000155: [Map] in ReadOnlySpace
 - map: 0x04ca00000475 <MetaMap (0x04ca0000002d <null>)>
 - type: INTERNALIZED_ONE_BYTE_STRING_TYPE
 - instance size: variable
 - elements kind: HOLEY_ELEMENTS
 - enum length: invalid
 - stable_map
 - non-extensible
 - back pointer: 0x04ca00000011 <undefined>
 - prototype_validity cell: 0
 - instance descriptors (own) #0: 0x04ca00000779 <DescriptorArray[0]>
 - prototype: 0x04ca0000002d <null>
 - constructor: 0x04ca0000002d <null>
 - dependent code: 0x04ca00000755 <Other heap object (WEAK_ARRAY_LIST_TYPE)>
 - construction counter: 0
```

### TNode\<Object\>

We can just put it to Print
 
```cpp
Print(node)
```

Results same with above `Handle<T>`

## Snapshot

### snapshot compile error 

#### BIND and label

If BIND occur, it means different code chunk. What if the code chunk is not connected with label it will cause snapshot compile error.

```cpp
  // What if else? the flow is not connected.
  GotoIf(IsNullOrUndefined(flags), &if_flags_not_exist);
  //  ...

  // Start another block.
  BIND(&loop);
```

```
#
# Fatal error in ../../src/compiler/raw-machine-assembler.cc, line 817
# Binding label without closing previous block:
#    label:          (&loop:../../src/builtins/builtins-regexp-gen.cc:1535)
```

So even though BIND is placed by the execution flow, we should jump to the BIND.

```cpp
  // What if else
  GotoIf(IsNullOrUndefined(flags), &if_flags_not_exist);
  // ...

  Goto(&loop);
  // Start another block.
  BIND(&loop);
```


# Runtime

## StackTrace

Print stack trace:

```cpp
#include "src/base/debug/stack_trace.h"
// ...
  base::debug::StackTrace stack;
  stack.Print(); // or std::string trace = stack.ToString();
// ...

```

example results:

```
==== C stack trace ===============================

    0   libv8_libbase.dylib                 0x0000000100fa2f70 v8::base::debug::StackTrace::StackTrace() + 32
    1   libv8_libbase.dylib                 0x0000000100fa2fac v8::base::debug::StackTrace::StackTrace() + 28
    2   libv8.dylib                         0x00000001146073d0 v8::internal::__RT_impl_Runtime_RegExpReplaceRT(v8::internal::Arguments<(v8::internal::ArgumentsType)0>, v8::internal::Isolate*) + 240
    3   libv8.dylib                         0x0000000114607094 v8::internal::Runtime_RegExpReplaceRT(int, unsigned long*, v8::internal::Isolate*) + 288
    4   ???                                 0x0000000307a37150 0x0 + 13013053776
    5   ???                                 0x0000000307cc72a4 0x0 + 13015741092
    6   ???                                 0x00000003077b2498 0x0 + 13010412696
```


## Turbofan

* [Turbolizer](https://v8.github.io/tools/head/turbolizer/index.html)

### Entrypoint of each phases related in Turbolizer

#### Turbofan

[Search `DECL_PIPELINE_PHASE_CONSTANTS` in pipeline.cc.](https://source.chromium.org/search?q=DECL_PIPELINE_PHASE_CONSTANTS%20path:v8)

#### TurboShaft
[Search `DECL_TURBOSHAFT_PHASE_CONSTANTS` or `DECL_TURBOSHAFT_PHASE_CONSTANTS_WITH_LEGACY_NAME`.](https://source.chromium.org/search?q=DECL_TURBOSHAFT_PHASE_CONSTANTS%20path:v8&sq=&ss=chromium%2Fchromium%2Fsrc)



## lldb

coming soon..
