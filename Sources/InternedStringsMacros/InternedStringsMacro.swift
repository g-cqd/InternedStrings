import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct InternedMacro: AccessorMacro, ExpressionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        let binding = try validatedBinding(from: declaration, attribute: node)
        let value = try propertyLiteralValue(from: node, binding: binding)
        let generated = GeneratedObfuscation.make(for: value, strategy: .standard, backend: .shared)

        let getter: AccessorDeclSyntax =
            """
            get {
                \(raw: generated.expressionSource)
            }
            """

        return [getter]
    }

    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        let input = try expressionInput(from: node, backend: backend(for: node))
        let expression: ExprSyntax = "\(raw: input.expressionSource)"
        return expression
    }
}

private enum StrategySpec {
    case standard
    case layered
}

private enum BackendSpec {
    case shared
    case inlined
}

private struct FreestandingInput {
    let expressionSource: String
}

private struct GeneratedObfuscation {
    let expressionSource: String

    static func make(for string: String, strategy: StrategySpec, backend: BackendSpec) -> GeneratedObfuscation {
        let inputBytes = Array(string.utf8)
        let keys: [UInt64] = switch strategy {
        case .standard:
            [UInt64.random(in: .min ... .max)]
        case .layered:
            [
                UInt64.random(in: .min ... .max),
                UInt64.random(in: .min ... .max),
            ]
        }

        let obfuscated = obfuscate(bytes: inputBytes, keys: keys)
        let bytesLiteral = formatBytesLiteral(obfuscated)
        let keyLiterals = keys.map(formatKeyLiteral)

        let expressionSource: String
        switch backend {
        case .shared:
            if keyLiterals.count == 1, let keyLiteral = keyLiterals.first {
                expressionSource = "SI.v([\(bytesLiteral)], \(keyLiteral))"
            } else {
                let keysLiteral = keyLiterals.joined(separator: ", ")
                expressionSource = "SI.v([\(bytesLiteral)], [\(keysLiteral)])"
            }
        case .inlined:
            expressionSource = inlineExpressionSource(bytesLiteral: bytesLiteral, keyLiterals: keyLiterals)
        }

        return GeneratedObfuscation(expressionSource: expressionSource)
    }

    private static func inlineExpressionSource(bytesLiteral: String, keyLiterals: [String]) -> String {
        let keysLiteral = keyLiterals.joined(separator: ", ")
        return """
        {
            func _internedNext(_ state: inout UInt64) -> UInt64 {
                state &+= 0x9E37_79B9_7F4A_7C15
                var z = state
                z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
                z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
                return z ^ (z >> 31)
            }

            func _internedDecode(_ data: [UInt8], _ key: UInt64) -> [UInt8] {
                let count = data.count
                guard count > 0 else { return [] }

                var shuffleState = key ^ 0xA5A5_A5A5_A5A5_A5A5
                var permutation = Array(0..<count)
                for index in stride(from: count - 1, through: 1, by: -1) {
                    permutation.swapAt(index, Int(_internedNext(&shuffleState) % UInt64(index + 1)))
                }

                var streamState = key ^ 0x5A5A_5A5A_5A5A_5A5A
                var output = [UInt8](repeating: 0, count: count)
                for (index, byte) in data.enumerated() {
                    output[permutation[index]] = byte ^ UInt8(truncatingIfNeeded: _internedNext(&streamState))
                }

                return output
            }

            var _internedBytes: [UInt8] = [\(bytesLiteral)]
            let _internedKeys: [UInt64] = [\(keysLiteral)]
            for _internedKey in _internedKeys.reversed() {
                _internedBytes = _internedDecode(_internedBytes, _internedKey)
            }

            return String(decoding: _internedBytes, as: UTF8.self)
        }()
        """
    }

    private static func obfuscate(bytes: [UInt8], keys: [UInt64]) -> [UInt8] {
        var result = bytes

        for key in keys {
            result = obfuscate(bytes: result, key: key)
        }

        return result
    }

    private static func obfuscate(bytes: [UInt8], key: UInt64) -> [UInt8] {
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

    private static func formatKeyLiteral(_ key: UInt64) -> String {
        "0x" + String(key, radix: 16, uppercase: true)
    }

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
}

private extension InternedMacro {
    static func validatedBinding(
        from declaration: some DeclSyntaxProtocol,
        attribute node: AttributeSyntax
    ) throws -> PatternBindingSyntax {
        guard let varDecl = declaration.as(VariableDeclSyntax.self) else {
            throw error(node, "@Interned can only be applied to a property")
        }

        guard varDecl.bindings.count == 1, let binding = varDecl.bindings.first else {
            throw error(node, "@Interned can only be applied to a single property")
        }

        guard binding.pattern.is(IdentifierPatternSyntax.self) else {
            throw error(node, "@Interned can only be applied to a named property")
        }

        guard binding.accessorBlock == nil else {
            throw error(node, "@Interned cannot be applied to properties with accessors or observers")
        }

        if let typeAnnotation = binding.typeAnnotation,
           !isStringType(typeAnnotation.type) {
            throw error(node, "@Interned can only be applied to String properties")
        }

        return binding
    }

    static func propertyLiteralValue(
        from attribute: AttributeSyntax,
        binding: PatternBindingSyntax
    ) throws -> String {
        if let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
           let first = arguments.first?.expression {
            return try wrap({
                try literalValue(
                    from: first,
                    nonLiteralMessage: "@Interned requires a string literal (as argument or initializer)",
                    interpolationMessage: "@Interned does not support string interpolation"
                )
            }, node: attribute)
        }

        if let initializer = binding.initializer?.value {
            return try wrap({
                try literalValue(
                    from: initializer,
                    nonLiteralMessage: "@Interned requires a string literal (as argument or initializer)",
                    interpolationMessage: "@Interned does not support string interpolation"
                )
            }, node: attribute)
        }

        throw error(attribute, "@Interned requires a string literal (as argument or initializer)")
    }

    static func expressionInput(
        from node: some FreestandingMacroExpansionSyntax,
        backend: BackendSpec
    ) throws -> FreestandingInput {
        let macroName = macroDisplayName(for: node)

        guard let firstArgument = node.arguments.first else {
            throw error(node, "\(macroName) requires a string literal or array literal of strings")
        }

        guard firstArgument.label == nil else {
            throw error(node, "\(macroName) requires an unlabeled value argument")
        }

        let strategy = try strategy(from: node.arguments.dropFirst(), node: node, macroName: macroName)

        if let array = firstArgument.expression.as(ArrayExprSyntax.self) {
            let values = try arrayLiteralValues(from: array, node: node, macroName: macroName)
            let expressions = values.map {
                GeneratedObfuscation.make(for: $0, strategy: strategy, backend: backend).expressionSource
            }
            return FreestandingInput(expressionSource: "[\(expressions.joined(separator: ", "))]")
        }

        let value = try wrap({
            try literalValue(
                from: firstArgument.expression,
                nonLiteralMessage: "\(macroName) requires a string literal or array literal of strings",
                interpolationMessage: "\(macroName) does not support string interpolation"
            )
        }, node: node)

        return FreestandingInput(
            expressionSource: GeneratedObfuscation.make(for: value, strategy: strategy, backend: backend).expressionSource
        )
    }

    static func strategy(
        from arguments: LabeledExprListSyntax.SubSequence,
        node: some SyntaxProtocol,
        macroName: String
    ) throws -> StrategySpec {
        guard let argument = arguments.first else {
            return .standard
        }

        guard arguments.count == 1 else {
            throw error(node, "\(macroName) supports at most one trailing strategy argument")
        }

        guard argument.label?.text == "strategy" else {
            throw error(node, "\(macroName) only supports a trailing 'strategy:' argument")
        }

        guard let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) else {
            throw error(node, "\(macroName) supports only .standard and .layered strategies")
        }

        switch memberAccess.declName.baseName.text {
        case "standard":
            return .standard
        case "layered":
            return .layered
        default:
            throw error(node, "\(macroName) supports only .standard and .layered strategies")
        }
    }

    static func arrayLiteralValues(
        from array: ArrayExprSyntax,
        node: some SyntaxProtocol,
        macroName: String
    ) throws -> [String] {
        try array.elements.map { element in
            try wrap({
                try literalValue(
                    from: element.expression,
                    nonLiteralMessage: "\(macroName) array elements must all be string literals",
                    interpolationMessage: "\(macroName) array elements do not support string interpolation"
                )
            }, node: node)
        }
    }

    static func literalValue(
        from expr: ExprSyntax,
        nonLiteralMessage: String,
        interpolationMessage: String
    ) throws -> String {
        guard let literal = expr.as(StringLiteralExprSyntax.self) else {
            throw LiteralValueError.message(nonLiteralMessage)
        }

        if literal.segments.count == 1,
           case let .stringSegment(segment) = literal.segments.first {
            return segment.content.text
        }

        if literal.segments.contains(where: { segment in
            if case .expressionSegment = segment {
                return true
            }
            return false
        }) {
            throw LiteralValueError.message(interpolationMessage)
        }

        throw LiteralValueError.message(nonLiteralMessage)
    }

    static func isStringType(_ type: TypeSyntax) -> Bool {
        let text = type.trimmed.description.filter { !$0.isWhitespace }
        return text == "String" || text == "Swift.String"
    }

    static func backend(for node: some FreestandingMacroExpansionSyntax) -> BackendSpec {
        switch node.macroName.text {
        case "InlinedInterned":
            .inlined
        default:
            .shared
        }
    }

    static func macroDisplayName(for node: some FreestandingMacroExpansionSyntax) -> String {
        "#\(node.macroName.text)"
    }

    static func error(_ node: some SyntaxProtocol, _ message: String) -> DiagnosticsError {
        DiagnosticsError(diagnostics: [
            Diagnostic(node: Syntax(node), message: InternedDiagnostic(message))
        ])
    }
}

private enum LiteralValueError: Error {
    case message(String)
}

private struct InternedDiagnostic: DiagnosticMessage {
    let message: String

    init(_ message: String) { self.message = message }

    var diagnosticID: MessageID {
        MessageID(domain: "InternedStrings", id: "error")
    }

    var severity: DiagnosticSeverity { .error }
}

private extension InternedMacro {
    static func wrap(_ operation: () throws -> String, node: some SyntaxProtocol) throws -> String {
        do {
            return try operation()
        } catch let LiteralValueError.message(message) {
            throw error(node, message)
        }
    }
}

private extension String {
    func paddedToTwo() -> String {
        count < 2 ? "0" + self : self
    }
}
