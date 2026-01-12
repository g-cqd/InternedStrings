// MARK: - Macro Declarations

/// Container for interned string properties.
///
/// Apply to an enum or extension containing `@Interned` properties.
/// Generates a shared key and obfuscated storage for all marked strings.
///
/// ```swift
/// @InternedStrings
/// enum Selectors {
///     @Interned("_privateSetFrame:") static var setFrame: String
///     @Interned("_privateGetBounds") static var getBounds: String
/// }
///
/// @InternedStrings
/// extension MyClass {
///     @Interned("_privateMethod") static var privateMethod: String
/// }
/// ```
@attached(member, names: arbitrary)
public macro InternedStrings() =
    #externalMacro(
        module: "InternedStringsMacros",
        type: "InternedStringsMacro"
    )

/// Marks a property for string interning.
///
/// Must be used within an `@InternedStrings` enum.
///
/// ```swift
/// @Interned("_privateMethod") static var method: String
/// ```
@attached(peer)
public macro Interned(_ value: String) =
    #externalMacro(
        module: "InternedStringsMacros",
        type: "InternedMacro"
    )
