#if DEBUG
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let message = items.map { String(describing: $0) }.joined(separator: separator)
    print(message, terminator: terminator)
}
#else
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {}
#endif
