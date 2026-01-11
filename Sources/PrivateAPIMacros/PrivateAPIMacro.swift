import Foundation
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct PrivateAPIMacro: AccessorMacro, PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let model = try Model(attribute: node, declaration: declaration, in: context)
        return [
            DeclSyntax("private static let \(raw: model.base64Identifier) = \(literal: model.base64)")
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        let model = try Model(attribute: node, declaration: declaration, in: context)

        return [
            AccessorDeclSyntax(
                accessorSpecifier: .keyword(.get),
                body: CodeBlockSyntax(
                    leftBrace: .leftBraceToken(leadingTrivia: .spaces(1), trailingTrivia: .newlines(1)),
                    statements: CodeBlockItemListSyntax {
                        CodeBlockItemSyntax(
                            item: .expr(
                                ExprSyntax(
                                    "PrivateAPIDecoder.decode(Self.\(raw: model.base64Identifier))"
                                )
                            )
                        )
                    },
                    rightBrace: .rightBraceToken(leadingTrivia: .newlines(0), trailingTrivia: .newlines(1))
                )
            )
        ]
    }
}

extension PrivateAPIMacro {
    struct Model {
        let base64Identifier: String
        let base64: String

        init(
            attribute: AttributeSyntax,
            declaration: some DeclSyntaxProtocol,
            in context: some MacroExpansionContext
        ) throws {
            guard let varDecl = declaration.as(VariableDeclSyntax.self),
                let binding = varDecl.bindings.first,
                varDecl.bindings.count == 1
            else {
                throw DiagnosticsError(diagnostics: [
                    Diagnostic(
                        node: Syntax(attribute),
                        message: Message("@PrivateAPI can only be applied to a single property"))
                ])
            }

            guard varDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
                throw DiagnosticsError(diagnostics: [
                    Diagnostic(node: Syntax(attribute), message: Message("@PrivateAPI requires 'var' (not 'let')"))
                ])
            }

            guard let propertyIdentifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else {
                throw DiagnosticsError(diagnostics: [
                    Diagnostic(
                        node: Syntax(attribute),
                        message: Message("@PrivateAPI can only be applied to identifier properties"))
                ])
            }

            guard binding.typeAnnotation != nil else {
                throw DiagnosticsError(diagnostics: [
                    Diagnostic(
                        node: Syntax(attribute), message: Message("@PrivateAPI requires an explicit ': String' type"))
                ])
            }

            let plainText = try Self.extractPlainText(attribute: attribute, binding: binding)
            base64Identifier = "__privateAPI_\(propertyIdentifier)_base64"
            base64 = Data(plainText.utf8).base64EncodedString()
        }

        private static func extractPlainText(
            attribute: AttributeSyntax,
            binding: PatternBindingSyntax
        ) throws -> String {
            if let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
                let first = arguments.first?.expression
            {
                return try extractStringLiteral(
                    from: first, errorMessage: "@PrivateAPI argument must be a string literal")
            }

            if let initializerValue = binding.initializer?.value {
                return try extractStringLiteral(
                    from: initializerValue, errorMessage: "@PrivateAPI initializer must be a string literal")
            }

            throw DiagnosticsError(diagnostics: [
                Diagnostic(
                    node: Syntax(attribute),
                    message: Message("@PrivateAPI requires a string literal argument or initializer"))
            ])
        }

        private static func extractStringLiteral(from expr: ExprSyntax, errorMessage: String) throws -> String {
            guard let literal = expr.as(StringLiteralExprSyntax.self) else {
                throw DiagnosticsError(diagnostics: [
                    Diagnostic(node: Syntax(expr), message: Message(errorMessage))
                ])
            }

            let segments = literal.segments
            guard segments.count == 1,
                case .stringSegment(let segment) = segments.first
            else {
                throw DiagnosticsError(diagnostics: [
                    Diagnostic(node: Syntax(expr), message: Message(errorMessage))
                ])
            }

            return segment.content.text
        }
    }

    struct Message: DiagnosticMessage {
        let message: String

        init(_ message: String) {
            self.message = message
        }

        var diagnosticID: MessageID {
            MessageID(domain: "PrivateAPIMacros", id: "PrivateAPI")
        }

        var severity: DiagnosticSeverity { .error }
    }
}
