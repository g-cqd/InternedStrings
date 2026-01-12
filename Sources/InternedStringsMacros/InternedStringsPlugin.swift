import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct InternedStringsPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        InternedStringsMacro.self
    ]
}
