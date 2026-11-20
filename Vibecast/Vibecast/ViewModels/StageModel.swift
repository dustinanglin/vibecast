import SwiftData
import Observation

enum StageContent {
    case empty
    case nowPlaying
    case show(Podcast)
}

/// Single source of truth for what covers or accompanies the Library: the
/// opened show and the player. With one pane these are a push and a sheet;
/// with two panes they live on the Stage. Keeping one `selected` podcast is
/// what lets the open show survive the device opening or closing.
@Observable
@MainActor
final class StageModel {
    private(set) var isTwoPane = false
    var isPlayerSheetPresented = false
    private var selected: Podcast?

    var shownPodcast: Podcast? {
        isTwoPane ? selected : nil
    }

    var pushedPodcast: Podcast? {
        get { isTwoPane ? nil : selected }
        set {
            // Going two-pane pops the pushed detail; SwiftUI then writes nil
            // here, which must not clear the show now on the Stage.
            guard !isTwoPane else { return }
            selected = newValue
        }
    }

    func openShow(_ podcast: Podcast) {
        selected = podcast
    }

    func closeShow() {
        selected = nil
    }

    func showNowPlaying() {
        if isTwoPane {
            selected = nil
        } else {
            isPlayerSheetPresented = true
        }
    }

    func setTwoPane(_ twoPane: Bool) {
        guard twoPane != isTwoPane else { return }
        isTwoPane = twoPane
        if twoPane { isPlayerSheetPresented = false }
    }

    func podcastsDidChange(existing: Set<PersistentIdentifier>) {
        guard let selected, !existing.contains(selected.persistentModelID) else { return }
        self.selected = nil
    }

    func content(hasLoadedEpisode: Bool) -> StageContent {
        if let shownPodcast { return .show(shownPodcast) }
        return hasLoadedEpisode ? .nowPlaying : .empty
    }

    func showsMiniPlayer(hasLoadedEpisode: Bool) -> Bool {
        guard hasLoadedEpisode else { return false }
        return !isTwoPane || shownPodcast != nil
    }
}
