//
//  VibecastApp.swift
//  Vibecast
//
//  Created by Dustin Anglin on 4/19/26.
//

import SwiftUI
import SwiftData

@main
struct VibecastApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Vibecast")
        }
        .modelContainer(for: [Podcast.self, Episode.self])
    }
}
