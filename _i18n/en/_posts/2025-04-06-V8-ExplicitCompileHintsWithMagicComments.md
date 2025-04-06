---
layout: post
title: V8 Explicit Compile Hints with Magic Comments
date:   2025-04-06 16:00:00+0900
categories: development
comments: true
languages:
- english
tags:
- Chromium
- V8
---

While following Chrome's development status, I found an interesting feature that will be shipped in Chrome M136 and V8 v13.6.

It's called **Explicit Compile Hints with Magic Comments**.

So let's see what it is.


Currently, v8 parses a [function lazily](https://v8.dev/blog/preparser) to reduce initial load times and optimize performance by only parsing code when it's executed.

To force eager parsing (parsing immediately), developers often use Immediately Invoked Function Expressions ([IIFE](https://developer.mozilla.org/en-US/docs/Glossary/IIFE)):
  ```js 
  (function () {
    // statements…
  })();
  ```

This is a well-known way of eager parsing via heuristic algorithms called Possibly Invoked Function Expressions ([PIFE](https://v8.dev/blog/preparser#pife)).

But [the WICG proposal](https://github.com/WICG/explicit-javascript-compile-hints-file-based?tab=readme-ov-file#the-pife-heuristic) said to use PIFE have some issues:

> Using PIFEs for triggering eager compilation has downsides, though. Especially:
>
> using it forces using function expressions instead of function declarations. The semantics of function expressions mandate doing the assignment, so they're generally less performant than function declarations. For browsers which don't follow the PIFE hint there's no upside.
> it cannot be applied to ES6 class methods
> Thus, we'd like to specify a more elegant way for triggering eager compilation.


To address this, the V8 team introduced **Explicit Compile Hints with Magic Comments** using special comments at the file scope. 

This feature is currently part of a WICG proposal ([Web Incubator Community Group](https://wicg.io/)), meaning it's not yet standardized by W3C or TC39.

> Note: TC39 is not the right place to discuss this, see [FAQ](https://github.com/WICG/explicit-javascript-compile-hints-file-based?tab=readme-ov-file#q-why-are-you-not-pursuing-standardizing-the-feature-via-tc39)


Let's break down in V8.

1.  [WICG: Explicit JavaScript Compile Hints (File-based)](https://wicg.github.io/explicit-javascript-compile-hints-file-based/)<br/>
  The spec introduces an internal slot \[[CompileHintAnnotation]] to hold the Compile Hint associated with the script / module.<br/>
  When the comment `// allFunctionsCalledOnLoad` occurs, set \[[CompileHintAnnotation]] to `"all"`. <br/>
  And the parser should use this information to parse eagerly.<br/>
  But note that the spec says *The user agent may also completely ignore the [[CompileHintAnnotation]] internal field.* <br/>
  For Example:
  ```javascript
    // allFunctionsCalledOnLoad
    function eagerlyCompiledFunction() {
    }
  ```
2. Let's see the implementation<br/>
  a. Scanner Detection<br/>
    The scanner in V8 checks for magic comments during the parsing phase:
    ```cpp
      void Scanner::TryToParseMagicComment(base::uc32 hash_or_at_sign) {
        // ...
          } else if (!saw_non_comment_ &&
                    name_literal ==
                        base::StaticOneByteVector("allFunctionsCalledOnLoad") &&
                    hash_or_at_sign == '#' && c0_ != '=') {
            // Over Here!
            saw_magic_comment_compile_hints_all_ = true;
          // I assume below is marking compiler hint per function.
          // I'm not sure if this feature is behind the feature flag.
          } else if (name_literal ==
                        base::StaticOneByteVector("functionsCalledOnLoad") &&
                    hash_or_at_sign == '#') {
            value = &per_function_compile_hints_value;
          } else {
            return;
        }
    ```
    Yeah, there seems to be a way to give compile hints for individual functions. But in this post I'll focus on  `allFunctionsCalledOnLoad`.<br/><br/>
  b. `saw_magic_comment_compile_hints_all_` is managed by scanner
    ```cpp
        bool SawMagicCommentCompileHintsAll() const {
          return saw_magic_comment_compile_hints_all_;
        }
    ```
  c. That information uses in `ParseFunctionLiteral` and `ParseArrowFunctionLiteral`:
    * ParseFunctionLiteral
      ```cpp
      FunctionLiteral* Parser::ParseFunctionLiteral(
          const AstRawString* function_name, Scanner::Location function_name_location,
          FunctionNameValidity function_name_validity, FunctionKind kind,
          int function_token_pos, FunctionSyntaxKind function_syntax_kind,
          LanguageMode language_mode,
          ZonePtrList<const AstRawString>* arguments_for_wrapped_function) {
        // ...
        FunctionLiteral::EagerCompileHint eager_compile_hint =
            function_state_->next_function_is_likely_called() || is_wrapped ||
                    params_need_validation ||
                    (info()->flags().compile_hints_magic_enabled() &&
                    // Over here!
                    scanner()->SawMagicCommentCompileHintsAll()) ||
                    (info()->flags().compile_hints_per_function_magic_enabled() &&
                    scanner()->HasPerFunctionCompileHint(compile_hint_position))
                ? FunctionLiteral::kShouldEagerCompile
                : default_eager_compile_hint();
          //...
        }
      ```
    * ParseArrowFunctionLiteral
      ```cpp
          template <typename Impl>
      typename ParserBase<Impl>::ExpressionT
      ParserBase<Impl>::ParseArrowFunctionLiteral(
          const FormalParametersT& formal_parameters, int function_literal_id,
          bool could_be_immediately_invoked) {
        //...
        int compile_hint_position = formal_parameters.scope->start_position();
        FunctionLiteral::EagerCompileHint eager_compile_hint =
            could_be_immediately_invoked ||
                    (compile_hints_magic_enabled_ &&
                    // Over here!
                    scanner_->SawMagicCommentCompileHintsAll()) ||
                    (compile_hints_per_function_magic_enabled_ &&
                    scanner_->HasPerFunctionCompileHint(compile_hint_position))
                ? FunctionLiteral::kShouldEagerCompile
                : default_eager_compile_hint_;
        // ...
        }
      ```
    These snippets demonstrate how the parser uses the detected compile hint to determine eager compilation.

This feature provides developers to explicitly hint the compiler to eagerly compile without the downsides of traditional methods. It will hold potential benefits for widely-used platforms like Chrome, Node.js, and Deno.
