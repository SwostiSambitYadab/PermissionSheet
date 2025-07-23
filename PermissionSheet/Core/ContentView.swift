//
//  ContentView.swift
//  PermissionSheet
//
//  Created by hb on 23/07/25.
//

import SwiftUI

struct ContentView: View {
    
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
        }
        .permissionSheet([.location, .camera, .microphone, .photoLibrary])
    }
}

#Preview {
    ContentView()
}
