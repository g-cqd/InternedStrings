# PrivateAPI

A Swift Macro for obfuscating sensitive string literals in your compiled binary.

`PrivateAPI` automatically encodes your string literals (like API keys, secrets, or endpoints) into Base64 at compile time. This prevents them from appearing as plain text in your application binary, protecting them from casual inspection tools like the `strings` command or basic hex editors.

## Features

- **Compile-Time Obfuscation**: Strings are converted to Base64 during compilation; the original plain text never enters the binary.
- **Zero Boilerplate**: simply attach the `@PrivateAPI` macro to your property.
- **Runtime Decoding**: Values are decoded on-the-fly when accessed.
- **Swift 6 Ready**: Built with strict concurrency and memory safety in mind.

## Requirements

- Swift 6.2+
- iOS 18.0+
- macOS 15.0+

## Installation

Add the package to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/g-cqd/PrivateAPI.git", branch: "main")
]
```

## Usage

You can use `@PrivateAPI` in two ways: passing the string as an argument or assigning it as an initializer.

### 1. As an Argument

```swift
import PrivateAPI

struct Secrets {
    @PrivateAPI("sk_live_123456789")
    var apiKey: String
}

// Usage
print(Secrets().apiKey) // "sk_live_123456789"
```

### 2. As an Initializer

```swift
import PrivateAPI

struct Config {
    @PrivateAPI
    var endpoint: String = "https://api.secret-service.com/v1"
}

// Usage
print(Config().endpoint) // "https://api.secret-service.com/v1"
```

## How It Works

The macro expands your code at compile time.

**Source Code:**
```swift
@PrivateAPI
var secret: String = "MyHiddenSecret"
```

**Expanded Code (Simplified):**
```swift
var secret: String {
    get {
        PrivateAPIDecoder.decode(Self.__privateAPI_secret_base64)
    }
}

private static let __privateAPI_secret_base64 = "TXlIaWRkZW5TZWNyZXQ=" // Base64 representation
```

## Disclaimer

**This is obfuscation, not encryption.**
While this prevents secrets from being readable in plain text within the binary, a determined attacker with reverse engineering tools (like a debugger or decompiler) can still retrieve the original values since the decoding logic and the Base64 string are both present in the app. Use this to deter casual inspection, but do not rely on it for protecting high-value secrets in hostile environments.
