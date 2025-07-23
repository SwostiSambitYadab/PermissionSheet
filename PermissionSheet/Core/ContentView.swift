//
//  ContentView.swift
//  PermissionSheet
//
//  Created by hb on 23/07/25.
//

import SwiftUI

struct ContentView: View {
    
    @Environment(\.openURL) private var openURL
    @State private var permission: [Permission] = Permission.allCases
    
    var body: some View {
        NavigationStack {
            List {
                let values = permission.filter { $0.isGranted == true }.map { $0.rawValue }
                if values.count > 0 {
                    Section("Usage") {
                        Text(values.joined(separator: ", "))
                            .font(.caption)
                            .bold()
                    }
                }
            }
            .navigationTitle("Permission Sheet")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "gear")
                        .onTapGesture {
                            if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                                openURL(appSettings)
                            }
                        }
                }
            }
        }
        .permissionSheet([.location, .camera, .microphone, .photoLibrary])
    }
}

#Preview {
    ContentView()
}
