# InternedStrings

A Swift macro package for compile-time string obfuscation.

Mark properties with `@Interned` and at compile time the macro:

- generates a random 64-bit key per property,
- obfuscates the string using permutation + XOR keystream, and
- emits a computed getter that reconstructs the original string on access.

## Features

- **Compile-Time Obfuscation**: No plaintext literals in the binary.
- **Stable Property API**: Keep using `@Interned` on string properties.
- **Additive Expression API**: Use `#Interned("value")` for local constants and inline expressions.
- **Curated Strategy Options**: Expression macros can opt into `.standard` or `.layered`.
- **Scalable Array Form**: Obfuscate arrays of string literals with `#Interned([...])`.
- **Alternate Decode Backend**: `#InlinedInterned(...)` emits an inline decode path instead of calling `SI.v`.
- **O(n) Decode**: Runtime reconstruction scales linearly with string length.
- **Lightweight Runtime**: Minimal `SI.v` decode helpers for single-pass and layered paths.
- **Flexible Forms**: Supports argument form `@Interned("value")` or initializer form `@Interned var x = "value"`.

## Requirements

- Swift 6.2+
- iOS 13.0+
- macOS 10.15+
- tvOS 13.0+
- watchOS 6.0+
- visionOS 1.0+
- Mac Catalyst 13.0+

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

### Basic

```swift
import InternedStrings

enum Selectors {
    @Interned static var setFrame = "_privateSetFrame:"
    @Interned("_privateGetBounds") static var getBounds: String
}

print(Selectors.setFrame)  // "_privateSetFrame:"
```

### Inline Expressions

```swift
import InternedStrings

let selector = #Interned("_privateSetFrame:")
let greeting = #Interned("Hello, World!")
```

### Strategy Selection

```swift
import InternedStrings

let standard = #Interned("hello")
let layered = #Interned("hello", strategy: .layered)
```

`@Interned` remains pinned to the standard strategy so existing property-based
call sites keep the same expansion model.

### Array Literals

```swift
import InternedStrings

let headers = #Interned([
    "X-Internal-Flag",
    "X-Private-Route",
])
```

### Inline Decode Backend

```swift
import InternedStrings

let shared = #Interned("runtime-helper")
let inlined = #InlinedInterned("inline-helper", strategy: .layered)
```

### Argument vs Initializer Form

```swift
// Argument form - value in macro parameter
@Interned("value") static var a: String

// Initializer form - value as property initializer
@Interned static var b = "value"
```

### Instance Properties

```swift
struct MyStruct {
    @Interned var message = "Hello, World!"
}

let s = MyStruct()
print(s.message)  // "Hello, World!"
```

## Expansion

**Source:**
```swift
@Interned static var secret = "password123"
```

**Expands to:**
```swift
static var secret = "password123" {
    get {
        SI.v([0x2A, 0x7F, ...], 0x1234567890ABCDEF)
    }
}
```

The initializer is syntactically present but semantically ignored because the getter provides the value.

## Constraints

- Value must be a string literal (as argument or initializer)
- `#Interned` requires either a string literal or an array literal of strings
- `#Interned(..., strategy:)` currently supports `.standard` and `.layered`
- `#InlinedInterned` mirrors the freestanding `#Interned` shapes but emits an inlined decode path
- `@Interned` cannot be applied to properties with accessors or observers

## Testing

The package includes comprehensive tests covering:

- **Roundtrip**: Empty, ASCII, Unicode/emoji, long strings, single character
- **Determinism**: Same key → same output, different keys → different output
- **Obfuscation Quality**: Output differs from input, no plaintext leakage
- **Macro Expansion**: Argument/initializer forms, static/instance properties
- **Additive APIs**: Freestanding strings, arrays, and layered strategy selection
- **Diagnostics**: Error messages for invalid usage

Run tests with:

```bash
swift test
bash scripts/release-leak-check.sh
```

## Disclaimer

**This is obfuscation, not encryption.** The decoding logic and obfuscated bytes are both present in the binary. A determined attacker with reverse engineering tools can retrieve the original values. Use this to deter casual inspection of strings in binaries, not to protect high-value secrets.
