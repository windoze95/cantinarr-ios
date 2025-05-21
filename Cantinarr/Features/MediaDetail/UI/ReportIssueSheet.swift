import SwiftUI

/// Placeholder sheet used to report problems with a media item.
struct ReportIssueSheet: View {
    @ObservedObject var vm: MediaDetailViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Text("Report issue UI goes here")
            .padding()
            .toolbar { Button("Done") { dismiss() } }
    }
}
