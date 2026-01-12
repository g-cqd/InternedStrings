import InternedStrings
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import InternedStringsMacros

@Suite("String Interning")
struct InternedStringsTests {
    // MARK: - Roundtrip Tests
    @Test("Empty string roundtrip")
    func emptyString() {
        let key: UInt64 = 0x1234_5678_9ABC_DEF0
        let original = ""
        let obfuscated = TestObfuscator.obfuscate(string: original, key: key)
        let decoded = SI.v(obfuscated, key)

        #expect(decoded == original)
        #expect(obfuscated.isEmpty)
    }

    @Test("ASCII string roundtrip")
    func asciiString() {
        let key: UInt64 = 0xDEAD_BEEF_CAFE_BABE
        let original = "_privateSetFrame:"
        let obfuscated = TestObfuscator.obfuscate(string: original, key: key)
        let decoded = SI.v(obfuscated, key)

        #expect(decoded == original)
        #expect(obfuscated.count == original.utf8.count)
    }

    @Test("Unicode/emoji roundtrip")
    func unicodeString() {
        let key: UInt64 = 0x0123_4567_89AB_CDEF
        let original = "Hello 世界 🌍 émojis"
        let obfuscated = TestObfuscator.obfuscate(string: original, key: key)
        let decoded = SI.v(obfuscated, key)

        #expect(decoded == original)
    }

    @Test("Long string roundtrip")
    func longString() {
        let key: UInt64 = 0xFFFF_FFFF_FFFF_FFFF
        let original = String(repeating: "abcdefghij", count: 100)
        let obfuscated = TestObfuscator.obfuscate(string: original, key: key)
        let decoded = SI.v(obfuscated, key)

        #expect(decoded == original)
    }

    @Test("Single character roundtrip")
    func singleChar() {
        let key: UInt64 = 0x0000_0000_0000_0001
        let original = "X"
        let obfuscated = TestObfuscator.obfuscate(string: original, key: key)
        let decoded = SI.v(obfuscated, key)

        #expect(decoded == original)
    }

    // MARK: - Determinism Tests

    @Test("Same key produces same output")
    func determinism() {
        let key: UInt64 = 0xABCD_EF01_2345_6789
        let original = "deterministic test"

        let first = TestObfuscator.obfuscate(string: original, key: key)
        let second = TestObfuscator.obfuscate(string: original, key: key)

        #expect(first == second)
    }

    @Test("Different keys produce different output")
    func keyDivergence() {
        let original = "same input"

        let first = TestObfuscator.obfuscate(string: original, key: 0x1111)
        let second = TestObfuscator.obfuscate(string: original, key: 0x2222)

        #expect(first != second)
    }

    // MARK: - Obfuscation Quality Tests

    @Test("Output differs from input bytes")
    func obfuscationDiffers() {
        let key: UInt64 = 0x9876_5432_1098_7654
        let original = "test string"
        let originalBytes = Array(original.utf8)
        let obfuscated = TestObfuscator.obfuscate(string: original, key: key)

        // At least some bytes should differ (overwhelmingly likely)
        let differentCount = zip(originalBytes, obfuscated).filter { $0 != $1 }.count
        #expect(differentCount > originalBytes.count / 2)
    }

    @Test("Output does not contain plaintext substrings")
    func noPlaintextLeakage() {
        let key: UInt64 = 0xFEDC_BA98_7654_3210
        let original = "_privateSetFrame:"
        let obfuscated = TestObfuscator.obfuscate(string: original, key: key)

        // Check that no 4+ byte substring of original appears in obfuscated
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

// MARK: - Test Helper (Mirrors Macro Logic)

/// Test-only obfuscator that mirrors the macro's compile-time logic.
enum TestObfuscator {
    static func obfuscate(string: String, key: UInt64) -> [UInt8] {
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

        // Permute bytes
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
