# Working in `InternedStrings`

Thin compatibility shim re-exporting `InternedStrings` from `Aemi-Studio/aemi` (`g-cqd/InternedStrings`).

## Engineering principles

- **Verify claims with executable checks.** Write a failing test or measurement before changing behaviour; never state unmeasured performance or unverified behaviour as fact.
- **Strictness.** Swift 6 language mode, strict concurrency, strict memory safety where configured, and warnings as errors. No force-unwraps or force-casts in production paths.
- **Bounded work and safety.** Bound untrusted inputs, recursion depth, and memory before allocation; handle errors explicitly without crashing on hostile input.
- **Factual documentation.** Keep `README.md`, user docs, and `Package.swift` aligned with the current codebase—no roadmaps, speculative plans, or diary logs in public docs.

## Commands

```sh
swift test
```

## Architecture records

Accepted architectural decisions live in `docs/adr/` (when present). Only add a new ADR for durable architectural choices; mark superseded records clearly.
