//
//  Cira_App.swift
//  Cira-
//
//  Created by Tu Huynh on 1/12/25.
//

import SwiftUI
import SwiftData

@main
struct Cira_App: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Photo.self,
            VoiceNote.self,
            Chapter.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            SplashView()
        }
        .modelContainer(sharedModelContainer)
    }
}
