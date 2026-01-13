# InternedStrings

A Swift macro package for compile-time string obfuscation.

Mark properties with `@Interned` and at compile time the macro:

- generates a random 64-bit key per property,
- obfuscates the string using permutation + XOR keystream, and
- emits a computed getter that reconstructs the original string on access.

## Features

- **Compile-Time Obfuscation**: No plaintext literals in the binary.
- **Simple API**: Just add `@Interned` to any string property.
- **O(n) Decode**: Runtime reconstruction scales linearly with string length.
- **Lightweight Runtime**: Single `SI.v([UInt8], UInt64) -> String` function.
- **Flexible Forms**: Supports argument form `@Interned("value")` or initializer form `@Interned var x = "value"`.

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

### Basic

```swift
import InternedStrings

enum Selectors {
    @Interned static var setFrame = "_privateSetFrame:"
    @Interned("_privateGetBounds") static var getBounds: String
}

print(Selectors.setFrame)  // "_privateSetFrame:"
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
- Cannot be applied to computed properties (already have getters)

## Testing

The package includes comprehensive tests covering:

- **Roundtrip**: Empty, ASCII, Unicode/emoji, long strings, single character
- **Determinism**: Same key → same output, different keys → different output
- **Obfuscation Quality**: Output differs from input, no plaintext leakage
- **Macro Expansion**: Argument/initializer forms, static/instance properties
- **Diagnostics**: Error messages for invalid usage

Run tests with:

```bash
swift test
```

## Disclaimer

**This is obfuscation, not encryption.** The decoding logic and obfuscated bytes are both present in the binary. A determined attacker with reverse engineering tools can retrieve the original values. Use this to deter casual inspection of strings in binaries, not to protect high-value secrets.
