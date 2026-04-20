import SwiftUI

struct PodcastDetailView: View {
    let podcast: Podcast

    var body: some View {
        Text("Detail for \(podcast.title)")
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
    }
}
