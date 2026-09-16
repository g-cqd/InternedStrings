import InternedStrings
import Testing

private enum Values {
    @Interned static var attached = "shared\nvalue"
}

@Test
func `legacy product expands attached and expression macros`() {
    #expect(Values.attached == "shared\nvalue")
    #expect(#Interned("shared\nvalue") == Values.attached)
    #expect(#Interned(["", "👩‍💻", "quote\""], strategy: .layered) == ["", "👩‍💻", "quote\""])
    #expect(#InlinedInterned(["one", "two"], strategy: .layered) == ["one", "two"])
}
