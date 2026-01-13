import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - Interned (Accessor Macro)

public struct InternedMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        // 1. Validate it's a variable declaration
        guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
            throw error(node, "@Interned can only be applied to a property")
        }

        // 2. Must be a single binding
        guard varDecl.bindings.count == 1, let binding = varDecl.bindings.first else {
            throw error(node, "@Interned can only be applied to a single property")
        }

        // 3. Must not already have accessors
        guard binding.accessorBlock == nil else {
            throw error(node, "@Interned cannot be applied to a computed property")
        }

        // 4. Extract the string value
        guard let value = extractValue(from: node, binding: binding) else {
            throw error(node, "@Interned requires a string literal (as argument or initializer)")
        }

        // 5. Generate key and obfuscate
        let key = UInt64.random(in: .min ... .max)
        let obfuscatedBytes = obfuscate(string: value, key: key)
        let bytesLiteral = formatBytesLiteral(obfuscatedBytes)

        // 6. Generate getter
        let getter: AccessorDeclSyntax =
            """
            get {
                SI.v([\(raw: bytesLiteral)], \(literal: key))
            }
            """

        return [getter]
    }

    // MARK: - Value Extraction

    private static func extractValue(from attribute: AttributeSyntax, binding: PatternBindingSyntax) -> String? {
        // Try attribute argument: @Interned("value")
        if let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
           let first = arguments.first?.expression,
           let text = extractStringLiteral(from: first) {
            return text
        }

        // Try initializer: @Interned var x = "value"
        if let initializer = binding.initializer?.value,
           let text = extractStringLiteral(from: initializer) {
            return text
        }

        return nil
    }

    private static func extractStringLiteral(from expr: ExprSyntax) -> String? {
        guard let literal = expr.as(StringLiteralExprSyntax.self),
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
