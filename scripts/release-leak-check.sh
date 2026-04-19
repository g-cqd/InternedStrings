#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workdir="$(mktemp -d)"

cleanup() {
    rm -rf "$workdir"
}
trap cleanup EXIT

mkdir -p "$workdir/Sources/LeakCheck"

cat > "$workdir/Package.swift" <<EOF
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LeakCheck",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        .package(path: "$repo_root")
    ],
    targets: [
        .executableTarget(
            name: "LeakCheck",
            dependencies: [
                .product(name: "InternedStrings", package: "InternedStrings")
            ]
        )
    ]
)
EOF

cat > "$workdir/Sources/LeakCheck/main.swift" <<'EOF'
import InternedStrings

enum PropertySecrets {
    @Interned static var property = "property-secret"
}

@main
struct LeakCheck {
    static func main() {
        let values = [
            PropertySecrets.property,
            #Interned("shared-secret", strategy: .layered),
            #InlinedInterned("inline-secret", strategy: .layered),
            #Interned(["array-one", "array-two"]).joined(separator: ","),
            #InlinedInterned(["inline-array-one", "inline-array-two"]).joined(separator: ","),
        ]

        print(values.joined(separator: "|").count)
    }
}
EOF

swift build --package-path "$workdir" -c release --product LeakCheck >/dev/null

binary_path="$(find "$workdir/.build" -type f -name LeakCheck -perm -111 | head -n 1)"

if [[ -z "$binary_path" ]]; then
    echo "Release leak check failed: executable not found" >&2
    exit 1
fi

for secret in \
    "property-secret" \
    "shared-secret" \
    "inline-secret" \
    "array-one" \
    "array-two" \
    "inline-array-one" \
    "inline-array-two"
do
    if strings "$binary_path" | grep -Fq "$secret"; then
        echo "Release leak check failed: found plaintext '$secret' in $binary_path" >&2
        exit 1
    fi
done

echo "Release leak check passed: no plaintext secrets found in $binary_path"
