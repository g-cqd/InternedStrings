// MARK: - Macro Declarations

/// Container for interned string properties.
///
/// Apply to an enum or extension containing `@Interned` properties.
/// Generates a shared key and obfuscated storage for all marked strings.
///
/// ```swift
/// @InternedStrings
/// enum Selectors {
///     @Interned("_privateSetFrame:") static var setFrame
///     @Interned var getBounds = "_privateGetBounds"
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
/// Must be used within an `@InternedStrings` container.
/// Value can be provided as argument or initializer.
///
/// ```swift
/// @Interned("value") static var name
/// @Interned var name = "value"
/// ```
@attached(peer)
public macro Interned(_ value: String) =
    #externalMacro(
        module: "InternedStringsMacros",
        type: "InternedMacro"
    )

/// Marks a property for string interning using an initializer.
@attached(peer)
public macro Interned() =
    #externalMacro(
        module: "InternedStringsMacros",
        type: "InternedMacro"
    )
