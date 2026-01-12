import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - InternedStrings

public struct InternedStringsMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(EnumDeclSyntax.self) || declaration.is(ExtensionDeclSyntax.self) else {
            throw error(node, "@InternedStrings can only be applied to an enum or extension")
        }

        let properties = try collectInternedProperties(from: declaration)

        guard !properties.isEmpty else {
            throw error(node, "@InternedStrings requires at least one @Interned property")
        }

        let key = UInt64.random(in: .min ... .max)

        var declarations: [DeclSyntax] = [
            "private static let _k: UInt64 = \(literal: key)"
        ]

        for property in properties {
            let obfuscatedBytes = obfuscate(string: property.value, key: key)
            let bytesLiteral = formatBytesLiteral(obfuscatedBytes)

            declarations.append(
                "private static let _\(raw: property.name): [UInt8] = [\(raw: bytesLiteral)]"
            )

            declarations.append(
                """
                static var \(raw: property.name): String {
                    SI.v(_\(raw: property.name), _k)
                }
                """
            )
        }

        return declarations
    }

    // MARK: - Property Collection

    private static func collectInternedProperties(
        from declaration: some DeclGroupSyntax
    ) throws -> [(name: String, value: String)] {
        var properties: [(name: String, value: String)] = []

        for member in declaration.memberBlock.members {
            guard let varDecl = member.decl.as(VariableDeclSyntax.self),
                  let attribute = findInternedAttribute(in: varDecl.attributes)
            else {
                continue
            }

            guard varDecl.bindings.count == 1, let binding = varDecl.bindings.first else {
                throw error(attribute, "@Interned can only be applied to a single property")
            }

            guard varDecl.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) else {
                throw error(attribute, "@Interned property must be static")
            }

            guard varDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
                throw error(attribute, "@Interned requires 'var' (not 'let')")
            }

            guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                throw error(attribute, "@Interned requires a simple identifier")
            }

            guard binding.typeAnnotation != nil else {
                throw error(attribute, "@Interned requires explicit type annotation ': String'")
            }

            guard binding.initializer == nil else {
                throw error(attribute, "@Interned value must be in attribute argument, not initializer")
            }

            guard let value = extractValue(from: attribute) else {
                throw error(attribute, "@Interned requires a string literal argument")
            }

            properties.append((identifier, value))
        }

        return properties
    }

    private static func findInternedAttribute(in attributes: AttributeListSyntax) -> AttributeSyntax? {
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

    private static func extractValue(from attribute: AttributeSyntax) -> String? {
        guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
              let first = arguments.first?.expression,
              let literal = first.as(StringLiteralExprSyntax.self),
              literal.segments.count == 1,
              case let .stringSegment(segment) = literal.segments.first
        else {
            return nil
        }
        return segment.content.text
    }

    // MARK: - Obfuscation

    private static func obfuscate(string: String, key: UInt64) -> [UInt8] {
        let bytes = Array(string.utf8)
        let n = bytes.count

        guard n > 0 else { return [] }

        var shuffleGen = SplitMix64(seed: key ^ 0xA5A5_A5A5_A5A5_A5A5)
        var permutation = Array(0..<n)

        for i in stride(from: n - 1, through: 1, by: -1) {
            permutation.swapAt(i, Int(shuffleGen.next() % UInt64(i + 1)))
        }

        var permuted = [UInt8](repeating: 0, count: n)
        for i in 0..<n {
            permuted[i] = bytes[permutation[i]]
        }

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

    // MARK: - PRNG

    private struct SplitMix64 {
        private var state: UInt64

        init(seed: UInt64) { state = seed }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    // MARK: - Diagnostics

    private static func error(_ node: some SyntaxProtocol, _ message: String) -> DiagnosticsError {
        DiagnosticsError(diagnostics: [
            Diagnostic(node: Syntax(node), message: InternedDiagnostic(message))
        ])
    }
}

// MARK: - Interned (Marker)

public struct InternedMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

// MARK: - Diagnostics

private struct InternedDiagnostic: DiagnosticMessage {
    let message: String

    init(_ message: String) { self.message = message }

    var diagnosticID: MessageID {
        MessageID(domain: "InternedStrings", id: "error")
    }

    var severity: DiagnosticSeverity { .error }
}

// MARK: - Helpers

private extension String {
    func paddedToTwo() -> String {
        count < 2 ? "0" + self : self
    }
}
