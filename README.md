# InternedStrings compatibility package

The implementation now lives in [Aemi](https://github.com/Aemi-Studio/aemi).
This package preserves the `InternedStrings` product and import through the published
Aemi `main` branch. Attached, expression, array, layered, and inlined macros share
one implementation and diagnostic test suite in Aemi.

For new consumers, select Aemi's `InternedStrings` product directly.

## Requirements

Swift 6.3+. iOS 18, macOS 15, tvOS 18, watchOS 11, visionOS 2, or Mac Catalyst 18.
The previous standalone implementation remains in this repository's Git history
for applications that still require older deployment targets.

## Verification

Run `swift test` to check imports and macro expansion through the compatibility product.

## License

[MIT](LICENSE).
