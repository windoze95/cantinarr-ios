import SwiftUI

/// Simple capsule shaped pill displaying the provided item's name using a key path.
struct PillView<Item>: View {
    let item: Item
    let nameKeyPath: KeyPath<Item, String>

    init(item: Item, nameKeyPath: KeyPath<Item, String>) {
        self.item = item
        self.nameKeyPath = nameKeyPath
    }

    var body: some View {
        Text(item[keyPath: nameKeyPath])
            .font(.caption)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            .foregroundColor(.accentColor)
            .lineLimit(1)
    }
}

extension PillView where Item == String {
    init(text: String) {
        self.init(item: text, nameKeyPath: \.self)
    }
}

#if DEBUG
private struct PillView_Previews: PreviewProvider {
    static var previews: some View {
        PillView(text: "Example")
            .previewLayout(.sizeThatFits)
    }
}
#endif
