import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct InternedStringsPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        InternedMacro.self,
    ]
}
