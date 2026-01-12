import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - InternedStrings (Container Macro)

/// Marks a type containing `@Interned` string properties.
/// Generates a shared key and storage for all interned strings within the type.
public struct InternedStringsMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let properties = collectInternedProperties(from: declaration)

        guard !properties.isEmpty else {
            return []
        }

        // Generate a truly random key at macro expansion time
        let key = UInt64.random(in: .min ... .max)

        var declarations: [DeclSyntax] = [
            "private static let _interned_k: UInt64 = \(literal: key)"
        ]

        for property in properties {
            let obfuscatedBytes = obfuscate(string: property.value, key: key)
            let bytesLiteral = formatBytesLiteral(obfuscatedBytes)

            declarations.append(
                "private static let _interned_\(raw: property.name): [UInt8] = [\(raw: bytesLiteral)]"
            )

            declarations.append(
                """
                static var \(raw: property.name): String {
                    SI.v(_interned_\(raw: property.name), _interned_k)
                }
                """
            )
        }

        return declarations
    }

    // MARK: - Property Collection

    private static func collectInternedProperties(
        from declaration: some DeclGroupSyntax
    ) -> [(name: String, value: String)] {
        declaration.memberBlock.members.compactMap { member -> (name: String, value: String)? in
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                let binding = varDecl.bindings.first,
                let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                let attribute = findInternedAttribute(in: varDecl.attributes),
                let value = extractValue(from: attribute, binding: binding)
            else {
                return nil
            }

            return (identifier, value)
        }
    }

    private static func findInternedAttribute(
        in attributes: AttributeListSyntax
    ) -> AttributeSyntax? {
        for attribute in attributes {
            guard let attr = attribute.as(AttributeSyntax.self),
                let identifier = attr.attributeName.as(IdentifierTypeSyntax.self),
                identifier.name.text == "Interned"
            else {
                continue
            }
            return attr
        }
        return nil
    }

    private static func extractValue(
        from attribute: AttributeSyntax,
        binding: PatternBindingSyntax
    ) -> String? {
        // Try attribute argument first: @Interned("value")
        if let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
            let first = arguments.first?.expression,
            let literal = first.as(StringLiteralExprSyntax.self),
            let segment = literal.segments.first?.as(StringSegmentSyntax.self)
        {
            return segment.content.text
        }

        // Fall back to initializer: @Interned var x = "value"
        if let initializer = binding.initializer?.value,
            let literal = initializer.as(StringLiteralExprSyntax.self),
            let segment = literal.segments.first?.as(StringSegmentSyntax.self)
        {
            return segment.content.text
        }

        return nil
    }

    // MARK: - Obfuscation (Encode)

    private static func obfuscate(string: String, key: UInt64) -> [UInt8] {
        let bytes = Array(string.utf8)
        let n = bytes.count

        guard n > 0 else { return [] }

        // Generate permutation
        var shuffleGen = SplitMix64(seed: key ^ 0xA5A5_A5A5_A5A5_A5A5)
        var permutation = Array(0..<n)

        for i in stride(from: n - 1, through: 1, by: -1) {
            let j = Int(shuffleGen.next() % UInt64(i + 1))
            permutation.swapAt(i, j)
        }

        // Permute bytes: permuted[i] = bytes[permutation[i]]
        var permuted = [UInt8](repeating: 0, count: n)
        for i in 0..<n {
            permuted[i] = bytes[permutation[i]]
        }

        // XOR with keystream
        var streamGen = SplitMix64(seed: key ^ 0x5A5A_5A5A_5A5A_5A5A)
        var obfuscated = [UInt8](repeating: 0, count: n)

        for i in 0..<n {
            obfuscated[i] = permuted[i] ^ UInt8(truncatingIfNeeded: streamGen.next())
        }

        return obfuscated
    }

    private static func formatBytesLiteral(_ bytes: [UInt8]) -> String {
        bytes.map { "0x" + String($0, radix: 16, uppercase: true).paddedToTwo() }.joined(separator: ", ")
    }

    // MARK: - PRNG (Compile-Time)

    private struct SplitMix64 {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
}

// MARK: - Interned (Property Marker Macro)

/// Marks a property for string interning within an `@InternedStrings` container.
/// The macro itself is a no-op; `@InternedStrings` scans for these markers.
public struct InternedMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Validate usage
        guard let varDecl = declaration.as(VariableDeclSyntax.self),
            let binding = varDecl.bindings.first,
            varDecl.bindings.count == 1
        else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(
                    node: Syntax(node),
                    message: InternedDiagnostic("@Interned can only be applied to a single property")
                )
            ])
        }

        guard varDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(
                    node: Syntax(node),
                    message: InternedDiagnostic("@Interned requires 'var' (not 'let')")
                )
            ])
        }

        guard binding.pattern.as(IdentifierPatternSyntax.self) != nil else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(
                    node: Syntax(node),
                    message: InternedDiagnostic("@Interned can only be applied to identifier properties")
                )
            ])
        }

        // Ensure a value is provided
        let hasAttributeValue = node.arguments?.as(LabeledExprListSyntax.self)?.first != nil
        let hasInitializer = binding.initializer != nil

        guard hasAttributeValue || hasInitializer else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(
                    node: Syntax(node),
                    message: InternedDiagnostic("@Interned requires a string value as argument or initializer")
                )
            ])
        }

        // No peer declarations needed; @InternedStrings handles generation
        return []
    }
}

// MARK: - Diagnostics

private struct InternedDiagnostic: DiagnosticMessage {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var diagnosticID: MessageID {
        MessageID(domain: "InternedStringsMacros", id: "Interned")
    }

    var severity: DiagnosticSeverity { .error }
}

// MARK: - String Helpers

extension String {
    fileprivate func paddedToTwo() -> String {
        count < 2 ? "0" + self : self
    }
}
