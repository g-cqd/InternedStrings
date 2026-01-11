import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import PrivateAPIMacros

@Suite
struct PrivateAPIMacroTests {
    @Test
    func testPeerAndAccessorExpansion_WithArgument() {
        assertMacroExpansion(
            """
            struct S {
              @PrivateAPI("CAFilter")
              private static var filterClassName: String
            }
            """,
            expandedSource: """
                struct S {
                  private static let __privateAPI_filterClassName_base64 = \"Q0FGaWx0ZXI=\"
                  private static var filterClassName: String {
                    get {
                      PrivateAPIDecoder.decode(Self.__privateAPI_filterClassName_base64)
                    }
                  }
                }
                """,
            macros: [
                "PrivateAPI": PrivateAPIMacro.self
            ]
        )
    }

    @Test
    func testPeerAndAccessorExpansion_WithInitializer() {
        assertMacroExpansion(
            """
            struct S {
              @PrivateAPI
              private static var filterClassName: String = "CAFilter"
            }
            """,
            expandedSource: """
                struct S {
                  private static let __privateAPI_filterClassName_base64 = \"Q0FGaWx0ZXI=\"
                  private static var filterClassName: String {
                    get {
                      PrivateAPIDecoder.decode(Self.__privateAPI_filterClassName_base64)
                    }
                  }
                }
                """,
            macros: [
                "PrivateAPI": PrivateAPIMacro.self
            ]
        )
    }
}
