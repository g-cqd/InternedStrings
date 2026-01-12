# InternedStrings

A Swift macro package that generates interned, obfuscated string accessors.

Annotate a container type with `@InternedStrings` and mark each string with `@Interned`. At compile time the macro:

- picks a random 64-bit key,
- obfuscates each UTF-8 byte payload using a deterministic permutation + XOR keystream, and
- generates `static` computed properties that reconstruct the original string on access.

## Features

- **Compile-Time Obfuscation**: No plaintext string literal is emitted in source expansion.
- **Deterministic Decode**: Runtime reconstruction is `O(n)` over the byte count.
- **Batch-Friendly**: One shared key per container type.
- **SwiftPM-Friendly**: Runtime is a tiny `SI.v([UInt8], UInt64) -> String` helper.

## Requirements

- Swift 6.2+
- iOS 14.0+
- macOS 11.0+

## Installation

Add the package to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/g-cqd/PrivateAPI.git", branch: "main")
]
```

Then add the product to your target:

```swift
.target(
    name: "MyTarget",
    dependencies: [
        .product(name: "InternedStrings", package: "InternedStrings"),
    ]
)
```

## Usage

Use `@InternedStrings` on a container and `@Interned` on each property.

### 1. As an Argument

```swift
import InternedStrings

@InternedStrings
enum PrivateStrings {
    @Interned("CAFilter") static var filterClassName: String
}

// Usage
print(PrivateStrings.filterClassName) // "CAFilter"
```

### 2. As an Initializer

```swift
import InternedStrings

@InternedStrings
enum PrivateStrings {
    @Interned static var filterMethodName: String = "filterWithType:"
}

// Usage
print(PrivateStrings.filterMethodName) // "filterWithType:"
```

## Notes

- `@Interned` requires `var` (not `let`).
- `@Interned` requires a string literal argument or initializer (no interpolation).
- `@InternedStrings` currently generates `static` accessors; use `static var`.

## How It Works

The macro expands your code at compile time.

**Source Code:**
```swift
@InternedStrings
enum Selectors {
    @Interned("_privateSetFrame:") static var setFrame: String
}
```

**Expanded Code (Simplified):**
```swift
private static let _interned_k: UInt64 = 1234567890
private static let _interned_setFrame: [UInt8] = [0xA1, 0xB2, 0xC3]

static var setFrame: String {
    SI.v(_interned_setFrame, _interned_k)
}
```

## Disclaimer

**This is obfuscation, not encryption.**
While this prevents secrets from being readable in plain text within the binary, a determined attacker with reverse engineering tools (like a debugger or decompiler) can still retrieve the original values since the decoding logic and the Base64 string are both present in the app. Use this to deter casual inspection, but do not rely on it for protecting high-value secrets in hostile environments.
