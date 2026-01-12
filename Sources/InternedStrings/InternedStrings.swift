import Foundation

// MARK: - Macro Declarations

/// Marks a type containing interned string properties.
///
/// Apply to an enum or struct containing `@Interned` properties.
/// Generates optimized storage and accessors for all marked properties.
///
/// ```swift
/// @InternedStrings
/// enum Selectors {
///     @Interned("_privateSetFrame:") static var setFrame: String
///     @Interned("_privateGetBounds") static var getBounds: String
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
/// Use within an `@InternedStrings` container. Provide the string value
/// either as an argument or as an initializer:
///
/// ```swift
/// @Interned("value") static var name: String      // Argument form
/// @Interned static var name: String = "value"     // Initializer form
/// ```
@attached(peer)
@attached(accessor)
public macro Interned(_ value: String) =
    #externalMacro(
        module: "InternedStringsMacros",
        type: "InternedMacro"
    )

/// Marks a property for string interning using an initializer value.
@attached(peer)
@attached(accessor)
public macro Interned() =
    #externalMacro(
        module: "InternedStringsMacros",
        type: "InternedMacro"
    )
