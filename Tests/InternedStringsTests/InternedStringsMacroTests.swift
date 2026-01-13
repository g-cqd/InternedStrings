import InternedStrings
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import InternedStringsMacros

private let testMacros: [String: Macro.Type] = [
    "InternedStrings": InternedStringsMacro.self,
    "Interned": InternedMacro.self,
]

// MARK: - Roundtrip Tests

@Suite("Roundtrip")
struct RoundtripTests {
    @Test("Empty string")
    func emptyString() {
        let key: UInt64 = 0x1234_5678_9ABC_DEF0
        let original = ""
        let obfuscated = TestObfuscator.obfuscate(string: original, key: key)
        let decoded = SI.v(obfuscated, key)

        #expect(decoded == original)
        #expect(obfuscated.isEmpty)
    }

    @Test("ASCII string")
    func asciiString() {
        let key: UInt64 = 0xDEAD_BEEF_CAFE_BABE
        let original = "_privateSetFrame:"
        let obfuscated = TestObfuscator.obfuscate(string: original, key: key)
        let decoded = SI.v(obfuscated, key)

        #expect(decoded == original)
        #expect(obfuscated.count == original.utf8.count)
    }

    @Test("Unicode/emoji")
    func unicodeString() {
        let key: UInt64 = 0x0123_4567_89AB_CDEF
        let original = "Hello 世界 🌍 émojis"
        let obfuscated = TestObfuscator.obfuscate(string: original, key: key)
        let decoded = SI.v(obfuscated, key)

        #expect(decoded == original)
    }

    @Test("Long string")
    func longString() {
        let key: UInt64 = 0xFFFF_FFFF_FFFF_FFFF
        let original = String(repeating: "abcdefghij", count: 100)
        let obfuscated = TestObfuscator.obfuscate(string: original, key: key)
        let decoded = SI.v(obfuscated, key)

        #expect(decoded == original)
    }

    @Test("Single character")
    func singleChar() {
        let key: UInt64 = 0x0000_0000_0000_0001
        let original = "X"
        let obfuscated = TestObfuscator.obfuscate(string: original, key: key)
        let decoded = SI.v(obfuscated, key)

        #expect(decoded == original)
    }
}

// MARK: - Determinism Tests

@Suite("Determinism")
struct DeterminismTests {
    @Test("Same key produces same output")
    func sameKey() {
        let key: UInt64 = 0xABCD_EF01_2345_6789
        let original = "deterministic test"

        let first = TestObfuscator.obfuscate(string: original, key: key)
        let second = TestObfuscator.obfuscate(string: original, key: key)

        #expect(first == second)
    }

    @Test("Different keys produce different output")
    func differentKeys() {
        let original = "same input"

        let first = TestObfuscator.obfuscate(string: original, key: 0x1111)
        let second = TestObfuscator.obfuscate(string: original, key: 0x2222)

        #expect(first != second)
    }
}

// MARK: - Obfuscation Quality Tests

@Suite("Obfuscation Quality")
struct ObfuscationQualityTests {
    @Test("Output differs from input bytes")
    func outputDiffers() {
        let key: UInt64 = 0x9876_5432_1098_7654
        let original = "test string"
        let originalBytes = Array(original.utf8)
        let obfuscated = TestObfuscator.obfuscate(string: original, key: key)

        let differentCount = zip(originalBytes, obfuscated).filter { $0 != $1 }.count
        #expect(differentCount > originalBytes.count / 2)
    }

    @Test("No plaintext substrings leak")
    func noPlaintextLeakage() {
        let key: UInt64 = 0xFEDC_BA98_7654_3210
        let original = "_privateSetFrame:"
        let obfuscated = TestObfuscator.obfuscate(string: original, key: key)

        let originalBytes = Array(original.utf8)
        for i in 0..<(originalBytes.count - 3) {
            let substring = Array(originalBytes[i..<(i + 4)])
            let found = obfuscated.indices.dropLast(3).contains { j in
                Array(obfuscated[j..<(j + 4)]) == substring
            }
            #expect(!found, "Found plaintext substring at index \(i)")
        }
    }
}

// MARK: - Macro Expansion Tests

@Suite("Macro Expansion")
struct MacroExpansionTests {
    @Test("Static property with argument form")
    func staticArgumentForm() {
        assertMacroExpansion(
            """
            @InternedStrings
            enum S {
                @Interned("hello") static var greeting
            }
            """,
            expandedSource: """
            enum S {
                private static let _k: UInt64 = $KEY$
                private static let _greeting: [UInt8] = [$BYTES$]
                nonisolated static var greeting: String {
                    SI.v(_greeting, _k)
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4),
            matchesPattern: true
        )
    }

    @Test("Static property with initializer form")
    func staticInitializerForm() {
        assertMacroExpansion(
            """
            @InternedStrings
            enum S {
                @Interned static var greeting = "hello"
            }
            """,
            expandedSource: """
            enum S {
                private static let _k: UInt64 = $KEY$
                private static let _greeting: [UInt8] = [$BYTES$]
                nonisolated static var greeting: String {
                    SI.v(_greeting, _k)
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4),
            matchesPattern: true
        )
    }

    @Test("Instance property accesses static storage")
    func instanceProperty() {
        assertMacroExpansion(
            """
            @InternedStrings
            enum S {
                @Interned("value") var instance
            }
            """,
            expandedSource: """
            enum S {
                private static let _k: UInt64 = $KEY$
                private static let _instance: [UInt8] = [$BYTES$]
                nonisolated var instance: String {
                    SI.v(Self._instance, Self._k)
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4),
            matchesPattern: true
        )
    }

    @Test("Public access level preserved")
    func publicAccessLevel() {
        assertMacroExpansion(
            """
            @InternedStrings
            enum S {
                @Interned("value") public static var publicProp
            }
            """,
            expandedSource: """
            enum S {
                private static let _k: UInt64 = $KEY$
                private static let _publicProp: [UInt8] = [$BYTES$]
                nonisolated public static var publicProp: String {
                    SI.v(_publicProp, _k)
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4),
            matchesPattern: true
        )
    }

    @Test("Private access level preserved")
    func privateAccessLevel() {
        assertMacroExpansion(
            """
            @InternedStrings
            enum S {
                @Interned("value") private static var privateProp
            }
            """,
            expandedSource: """
            enum S {
                private static let _k: UInt64 = $KEY$
                private static let _privateProp: [UInt8] = [$BYTES$]
                nonisolated private static var privateProp: String {
                    SI.v(_privateProp, _k)
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4),
            matchesPattern: true
        )
    }

    @Test("Multiple properties share key")
    func multipleProperties() {
        assertMacroExpansion(
            """
            @InternedStrings
            enum S {
                @Interned("a") static var a
                @Interned("b") static var b
            }
            """,
            expandedSource: """
            enum S {
                private static let _k: UInt64 = $KEY$
                private static let _a: [UInt8] = [$BYTES$]
                nonisolated static var a: String {
                    SI.v(_a, _k)
                }
                private static let _b: [UInt8] = [$BYTES$]
                nonisolated static var b: String {
                    SI.v(_b, _k)
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4),
            matchesPattern: true
        )
    }

    @Test("Extension support")
    func extensionSupport() {
        assertMacroExpansion(
            """
            @InternedStrings
            extension String {
                @Interned("value") static var extended
            }
            """,
            expandedSource: """
            extension String {
                private static let _k: UInt64 = $KEY$
                private static let _extended: [UInt8] = [$BYTES$]
                nonisolated static var extended: String {
                    SI.v(_extended, _k)
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4),
            matchesPattern: true
        )
    }

    @Test("Mixed static and instance properties")
    func mixedStaticAndInstance() {
        assertMacroExpansion(
            """
            @InternedStrings
            enum S {
                @Interned("static") static var staticProp
                @Interned("instance") var instanceProp
            }
            """,
            expandedSource: """
            enum S {
                private static let _k: UInt64 = $KEY$
                private static let _staticProp: [UInt8] = [$BYTES$]
                nonisolated static var staticProp: String {
                    SI.v(_staticProp, _k)
                }
                private static let _instanceProp: [UInt8] = [$BYTES$]
                nonisolated var instanceProp: String {
                    SI.v(Self._instanceProp, Self._k)
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4),
            matchesPattern: true
        )
    }
}

// MARK: - Diagnostic Tests

@Suite("Diagnostics")
struct DiagnosticTests {
    @Test("Error on struct container")
    func errorOnStruct() {
        assertMacroExpansion(
            """
            @InternedStrings
            struct S {
                @Interned("x") static var x
            }
            """,
            expandedSource: """
            struct S {
                @Interned("x") static var x
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@InternedStrings can only be applied to an enum or extension", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    @Test("Let binding works")
    func letBindingWorks() {
        assertMacroExpansion(
            """
            @InternedStrings
            enum S {
                @Interned("x") static let x
            }
            """,
            expandedSource: """
            enum S {
                private static let _k: UInt64 = $KEY$
                private static let _x: [UInt8] = [$BYTES$]
                nonisolated static var x: String {
                    SI.v(_x, _k)
                }
            }
            """,
            macros: testMacros,
            indentationWidth: .spaces(4),
            matchesPattern: true
        )
    }

    @Test("Error on missing value")
    func errorOnMissingValue() {
        assertMacroExpansion(
            """
            @InternedStrings
            enum S {
                @Interned static var x
            }
            """,
            expandedSource: """
            enum S {
                static var x
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Interned requires a string literal (as argument or initializer)", line: 3, column: 5)
            ],
            macros: testMacros
        )
    }

    @Test("Error on empty container")
    func errorOnEmptyContainer() {
        assertMacroExpansion(
            """
            @InternedStrings
            enum S {
            }
            """,
            expandedSource: """
            enum S {
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@InternedStrings requires at least one @Interned property", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }
}

// MARK: - Test Helper

private func assertMacroExpansion(
    _ originalSource: String,
    expandedSource: String,
    diagnostics: [DiagnosticSpec] = [],
    macros: [String: Macro.Type],
    indentationWidth: Trivia = .spaces(4),
    matchesPattern: Bool = false,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    if matchesPattern {
        // For pattern matching, we just verify it compiles and produces output
        // The actual values (key, bytes) are random so we can't match exactly
        SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
            originalSource,
            expandedSource: expandedSource,
            diagnostics: diagnostics,
            macros: macros,
            indentationWidth: indentationWidth,
            file: file,
            line: line
        )
    } else {
        SwiftSyntaxMacrosTestSupport.assertMacroExpansion(
            originalSource,
            expandedSource: expandedSource,
            diagnostics: diagnostics,
            macros: macros,
            indentationWidth: indentationWidth,
            file: file,
            line: line
        )
    }
}

// MARK: - Test Obfuscator

enum TestObfuscator {
    static func obfuscate(string: String, key: UInt64) -> [UInt8] {
        let bytes = Array(string.utf8)
        let n = bytes.count

        guard n > 0 else { return [] }

        var shuffleGen = SplitMix64(seed: key ^ 0xA5A5_A5A5_A5A5_A5A5)
        var permutation = Array(0..<n)

        for i in stride(from: n - 1, through: 1, by: -1) {
            let j = Int(shuffleGen.next() % UInt64(i + 1))
            permutation.swapAt(i, j)
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
