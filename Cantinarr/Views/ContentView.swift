import SwiftUI

struct ContentView: View {
    var body: some View {
        RootShellView()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(EnvironmentsStore())
            .environmentObject(UserSession())
            .environment(\.managedObjectContext,
                         PersistenceController.shared.container.viewContext)
    }
}
