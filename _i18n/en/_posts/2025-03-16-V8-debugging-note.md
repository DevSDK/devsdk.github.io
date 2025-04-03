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
toc: true
filepath: https://github.com/DevSDK/devsdk.github.io/blob/main/_i18n/en/_posts/2025-03-16-V8-debugging-note.md
---

# Debugging Note

This post simply contains a debugging note for V8 development for myself.

Please let me know if you know a more efficient way.

This post will be updated when I got something useful.


## TOOLS

[https://v8.github.io/tools/head/](https://v8.github.io/tools/head/)

## CSA

### Print

#### Handle\<T\>

To Print `Handle<T>` in CSA, we can use `HeapConstantNoHole`

```cpp

  Handle<String> name = DoSomething(); 
  auto temp = HeapConstantNoHole(name);
  Print(temp);
```

Result:

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

#### TNode\<Object\>

We can just put it to Print
 
```cpp
Print(node)
```

Results same with above `Handle<T>`

## Torque (.tq file)

### Print

you can find the Print() functions in [base.tq](https://source.chromium.org/chromium/chromium/src/+/main:v8/src/builtins/base.tq;l=714-721?q=base.tq)

It is same with CSA's.

```
extern macro Print(constexpr string): void;
extern macro Print(constexpr string, Object): void;
extern macro Print(Object): void;
extern macro Print(constexpr string, uintptr): void;
extern macro Print(constexpr string, float64): void;
extern macro PrintErr(constexpr string): void;
extern macro PrintErr(constexpr string, Object): void;
extern macro PrintErr(Object): void;
```


### Snapshot

#### snapshot compile error 

##### BIND and Label

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


## Runtime

### StackTrace

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


## Turbofan/TurboShaft

* [Turbolizer](https://v8.github.io/tools/head/turbolizer/index.html)

### Entrypoint of each phases related in Turbolizer

#### Turbofan

[Search `DECL_PIPELINE_PHASE_CONSTANTS` in pipeline.cc.](https://source.chromium.org/search?q=DECL_PIPELINE_PHASE_CONSTANTS%20path:v8)

#### TurboShaft
[Search `DECL_TURBOSHAFT_PHASE_CONSTANTS` or `DECL_TURBOSHAFT_PHASE_CONSTANTS_WITH_LEGACY_NAME`.](https://source.chromium.org/search?q=DECL_TURBOSHAFT_PHASE_CONSTANTS%20path:v8&sq=&ss=chromium%2Fchromium%2Fsrc)


## Assertions

###  DisallowGarbageCollection

Assert when GC potential operations occur.

Only for debugging build.

```
  {
    DisallowGarbageCollection no_gc;

    // some gc-safe operations.
    // e.g., Accessing char in the string.

    // if memory is allocated that could call GC in this block in here,
    // it will assert.
  }

```

## LLDB/GDB

We can use `lldb` or `gdb` to debug v8 (and chromium too).

The source must be compiled in debug build to create Debugging Symbols.

By debugger, you can stop the specific position of the source code and print the value. Even you can execute method and print the result like:

`(lldb) p this->ToString()`

GDB/LLDB command map: [https://lldb.llvm.org/use/map.html](https://lldb.llvm.org/use/map.html)

### Example in CLI
```bash
devsdk@MacBook-Pro ~/workspace/chromium/v8/v8/out/arm64.debug % lldb -- d8 ~/workspace/chromium/playground/temp.js
(lldb) target create "d8"
Current executable set to '/Users/devsdk/workspace/chromium/v8/v8/out/arm64.debug/d8' (arm64).
(lldb) settings set -- target.run-args  "/Users/devsdk/workspace/chromium/playground/temp.js"
(lldb) b src/parsing/parser-base.h:5910
Breakpoint 1: 2 locations.
(lldb) r
Process 49637 launched: '/Users/devsdk/workspace/chromium/v8/v8/out/arm64.debug/d8' (arm64)
0
Process 49637 stopped
* thread #1, queue = 'com.apple.main-thread', stop reason = breakpoint 1.2
    frame #0: 0x0000000113664f94 libv8.dylib`v8::internal::ParserBase<v8::internal::PreParser>::ParseBlock(this=0x000000014ae04a30, labels=0x0000000000000000, block_scope=0x000000014b010430) at parser-base.h:5910:3
   5907	    body->set_scope(scope()->FinalizeBlockScope());
   5908	  }
   5909
-> 5910	  body->InitializeStatements(statements, zone());
   5911	  return body;
   5912	}
   5913
Target 0: (d8) stopped.
(lldb) p body
(v8::internal::ParserBase<v8::internal::PreParser>::BlockT) {
  v8::internal::PreParserStatement = (code_ = kUnknownStatement)
  scope_ = nullptr
}
```

### VS Code Debugger Setup
```json
{
  // Use IntelliSense to learn about possible attributes.
  // Hover to view descriptions of existing attributes.
  // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
  "version": "0.2.0",
  "configurations": [
    {
      "name": "(lldb) Launch",
      "type": "cppdbg",
      "request": "launch",
      "program": "${workspaceFolder}/out/arm64.debug/d8",
      "args": ["/Users/devsdk/workspace/chromium/playground/temp.js"],
      "stopAtEntry": false,
      "cwd": "${workspaceFolder}/out/arm64.debug",
      "environment": [],
      "sourceFileMap" : {"../../src/": "${workspaceFolder}/src/"},
      "externalConsole": false,
      "MIMode": "lldb"
    }
  ]
}

```

---

## src/base

### ThreadedList\<T\>

ThreadedList is a linked list where each object acts as its own node—this is known as an intrusive linked list.

The linkage (i.e., next pointers) is embedded directly within the object rather than stored in a separate node wrapper.

> ⚠️ Note: Despite the name, ThreadedList is not related to thread safety or multithreading.
> It simply refers to “threading” objects together in a list.

To use an object `type T` with `ThreadedList<T>`, the class must expose the following static member functions:

```cpp
  static T** next(T* t) { return t->next(); }
  static T** start(T** t) { return t; }
  static T* const* start(T* const* t) { return t; }
```

These functions tell the list how to get and follow the next pointer in the object.

You can also customize the pointer accessor logic by specifying a second template parameter. For example:

```cpp
 base::ThreadedList<Variable, Variable::VarListNext>;
```

If you’re facing an issue where `Add` fails because the tail is not `nullptr`,

you’re likely trying to use the object in multiple lists at once.

For example,

```cpp
class Something {
  // ...
  base::ThreadedList<Variable> local_;
  base::ThreadedList<Variable> var_list_;
  // ...
}
```

This can cause Add to fail and not work as expected,

because both lists are sharing the same `next()` pointer from Variable.

To make this work correctly:

```cpp
class Variable {
  public:
  // ...

  struct VarListNext {
    static Variable** next(Variable* t) { return &t->var_next_; }
    static Variable** start(Variable** t) { return t; }
  };
  // ...
  private:
   Variable* next_;   // Used by local_
   Variable* var_next_; // Used by var_list_
}

class Something {
  base::ThreadedList<Variable> local_;
  base::ThreadedList<Variable, Variable::VarListNext> var_list_; 
};
```

Now each list uses its own next pointer, and the object can safely belong to both lists.