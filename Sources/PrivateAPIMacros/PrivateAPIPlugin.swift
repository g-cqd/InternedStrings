import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct PrivateAPIPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        PrivateAPIMacro.self
    ]
}
