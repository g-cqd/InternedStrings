import Foundation

@attached(peer, names: prefixed(__privateAPI_))
@attached(accessor)
public macro PrivateAPI(_ value: String? = nil) =
    #externalMacro(
        module: "PrivateAPIMacros",
        type: "PrivateAPIMacro"
    )

public enum PrivateAPIDecoder {
    @inlinable
    public static func decode(_ base64: String) -> String {
        guard let data = Data(base64Encoded: base64),
            let string = String(data: data, encoding: .utf8)
        else {
            preconditionFailure("Invalid base64")
        }

        return string
    }
}
