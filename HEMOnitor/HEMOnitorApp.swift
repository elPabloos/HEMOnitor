//
//  HEMOnitorApp.swift
//  HEMOnitor
//
//  Created by Ciudin, Paul-Catalin on 05.08.2025.
//

import SwiftUI

@main
struct HEMOnitorApp: App {
    init() {
        FontRegistrar.registerBundledFontsIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
