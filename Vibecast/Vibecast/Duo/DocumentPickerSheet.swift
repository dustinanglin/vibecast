import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The system file picker as plain sheet content. SwiftUI's `fileImporter`
/// presents the picker itself at full height, with no way to size it; hosting
/// the picker in our own sheet lets it follow `duoSheetPlacement()` and stay
/// in the lower half of a part-folded iPhone Duo.
struct DocumentPickerSheet: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    /// Called with the chosen files, or an empty array if the user cancelled.
    let onFinish: ([URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onFinish: ([URL]) -> Void

        init(onFinish: @escaping ([URL]) -> Void) {
            self.onFinish = onFinish
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onFinish(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onFinish([])
        }
    }
}
