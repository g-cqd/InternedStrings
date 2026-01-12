# InternedStrings

A Swift macro package for compile-time string obfuscation.

Annotate a container with `@InternedStrings` and mark properties with `@Interned("value")`. At compile time the macro:

- generates a random 64-bit key shared across all properties,
- obfuscates each string using permutation + XOR keystream, and
- emits computed properties that reconstruct the original string on access.

## Features

- **Compile-Time Obfuscation**: No plaintext literals in the expanded source.
- **Single Shared Key**: One key per container, minimal storage overhead.
- **O(n) Decode**: Runtime reconstruction scales linearly with string length.
- **Lightweight Runtime**: Single `SI.v([UInt8], UInt64) -> String` function.

## Requirements

- Swift 6.0+
- macOS 11.0+ / iOS 14.0+

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/g-cqd/InternedStrings.git", branch: "main")
]
```

Then add it to your target:

```swift
.target(
    name: "MyTarget",
    dependencies: ["InternedStrings"]
)
```

## Usage

```swift
import InternedStrings

@InternedStrings
enum Selectors {
    @Interned("_privateSetFrame:") static var setFrame: String
    @Interned("_privateGetBounds") static var getBounds: String
}

print(Selectors.setFrame)  // "_privateSetFrame:"
```

Works on extensions too:

```swift
@InternedStrings
extension MyClass {
    @Interned("_internalMethod") static var internalMethod: String
}
```

## Expansion

**Source:**
```swift
@InternedStrings
enum S {
    @Interned("secret") static var secret: String
}
```

**Expands to:**
```swift
enum S {
    private static let _k: UInt64 = 0x...
    private static let _secret: [UInt8] = [0x.., 0x.., ...]
    static var secret: String { SI.v(_secret, _k) }
}
```

## Constraints

- Container must be an `enum` or `extension`
- Properties must be `static var` with explicit `: String` type
- Value must be a string literal in the attribute: `@Interned("value")`
- No initializers: `@Interned static var x: String = "value"` is not allowed

## Disclaimer

**This is obfuscation, not encryption.** The decoding logic and obfuscated bytes are both present in the binary. A determined attacker with reverse engineering tools can retrieve the original values. Use this to deter casual inspection of strings in binaries, not to protect high-value secrets.
