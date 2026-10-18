# Swift 6.4 ownership compiler investigation

Original public-product reproducers are in this directory. `Reduced` contains
original Apache-2.0 reductions with no imports, private native meter or package
code. The class holds one mutable integer, the facade is noncopyable and the
synchronous entry borrows it. The defect persists without Foundation or JSON.

Replay with a selected installed compiler and the supported macOS SDK:

```sh
python3 -B Scripts/probe_composition_compiler.py --compiler /path/to/swiftc --output .build/composition-compiler
```

This investigation deliberately returns **2 when a compiler crash is observed**.
It is separate from the composition lane's intended diagnostic builds. Never
interpret a signal, stack dump or verifier failure as a passing negative test.
The receipt preserves the command, source/log hashes, version, exit and outcome.

Observed on Apple Swift 6.4.0.34.1 and Swift.org `swift-6.4-RELEASE`:

| Form | Outcome |
| --- | --- |
| Inferred borrowed closure parameter captured by nested synchronous helper | SIL ownership verifier crash |
| Explicit borrowing closure parameter, nested synchronous helper | Compiles |
| Inferred parameter captured by escaping closure | SIL ownership verifier crash |
| Explicit borrowing closure parameter, escaping capture | Intended borrowed-parameter diagnostic |
| Direct method reference, inferred or explicit borrowing parameter | SIL ownership verifier crash |
| Method reference from explicit borrowed helper | SIL ownership verifier crash |
| Explicit helper parameter with direct method call | Compiles |
| Escaping closure returned from explicit borrowed helper | Intended borrowed-parameter diagnostic |

The normal diagnostic is `'scope' cannot be captured by an escaping closure since
it is a borrowed parameter`. Crash diagnostics include `Have operand with
incompatible ownership?!` and `copy_addr`. These are observations on two specific
installed compilers; no claim is made about unexecuted newer releases.

Use an explicit borrowing closure parameter and direct calls, or pass the scope
as an explicit borrowing parameter to ordinary helpers. The independent consumer
executes the nested form, checks exact aggregate work/retention, and fails one unit
below completion. No lifetime experiment flag, copyable facade, unchecked
Sendable or arbitrary callback instruction claim is needed. The method-value forms
remain unqualified. No compiler issue has been sent on the maintainer's behalf.
