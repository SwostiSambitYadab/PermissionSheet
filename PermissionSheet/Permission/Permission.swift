//
//  Permission.swift
//  PermissionSheet
//
//  Created by hb on 23/07/25.
//

import SwiftUI
import CoreLocation
import PhotosUI
import AVKit

/// - Permissions
enum Permission: String, CaseIterable {
    case location = "Location Services"
    case camera = "Camera Access"
    case microphone = "Microphone Access"
    case photoLibrary = "Photo Library Access"
    
    var symbols: String {
        switch self {
        case .location: "location.fill"
        case .camera: "camera.fill"
        case .microphone: "microphone.fill"
        case .photoLibrary: "photo.stack.fill"
        }
    }
    
    var orderIndex: Int {
        switch self {
        case .camera: 0
        case .microphone: 1
        case .photoLibrary: 2
        case .location: 3
        }
    }
    
    var isGranted: Bool? {
        switch self {
        case .location:
            let status = CLLocationManager().authorizationStatus
            return status == .notDetermined ? nil : status == .authorizedWhenInUse || status == .authorizedAlways
        case .camera:
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            return status == .notDetermined ? nil : status == .authorized
        case .microphone:
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            return status == .notDetermined ? nil : status == .authorized
        case .photoLibrary:
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            /// LIMITED IS OPTIONAL
            return status == .notDetermined ? nil : status == .authorized || status == .limited
        }
    }
}

extension View {
    @ViewBuilder
    func permissionSheet(_ permissions: [Permission]) -> some View {
        self
            .modifier(PermissionSheetViewModifier(permissions: permissions))
    }
}

fileprivate struct PermissionSheetViewModifier: ViewModifier {
    
    init(permissions: [Permission]) {
        let initialStates = permissions.sorted(by: {
            $0.orderIndex < $1.orderIndex
        }).compactMap {
            PermissionState(id: $0)
        }
        _states = .init(initialValue: initialStates)
    }
    
    @Environment(\.openURL) private var openURL
    
    /// View Properties
    @State private var showSheet: Bool = false
    @State private var states: [PermissionState]
    @State private var currentIndex: Int = 0
    var locationManager = LocationManager()
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showSheet) {
                VStack {
                    Text("Required Permissions")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Image(systemName: isAllGranted ? "person.badge.shield.checkmark" : "person.badge.shield.exclamationmark")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 100, height: 100)
                        .background {
                            RoundedRectangle(cornerRadius: 30)
                                .fill(.blue.gradient)
                        }
                    
                    /// Permission Rows
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(states) { state in
                            permissionRow(state)
                                .onTapGesture {
                                    requestPermission(state.id.orderIndex)
                                }
                        }
                    }
                    .padding(.top)
                    
                    Spacer()
                    
                    Button {
                        showSheet = false
                    } label: {
                        Text("Start using the App")
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(.blue.gradient, in: .capsule)
                    }
                    .disabled(!isAllGranted)
                    .opacity(isAllGranted ? 1 : 0.6)
                    .overlay {
                        if isThereAnyRejection {
                            Button("Go to settings") {
                                if let applicationURL = URL(string: UIApplication.openSettingsURLString) {
                                    openURL(applicationURL)
                                }
                            }
                            .offset(y: -50)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .presentationDetents([.height(480)])
                .interactiveDismissDisabled()
            }
            .onChange(of: locationManager.status) { oldValue, newValue in
                if let status = locationManager.status,
                   let index = states.firstIndex(where: { $0.id == .location }) {
                    
                    if status == .notDetermined {
                        showSheet = true
                        states[index].isGranted = nil
                        /// Asking permission
                        requestPermission(index)
                    } else if status == .restricted || status == .denied {
                        showSheet = true
                        states[index].isGranted = false
                    } else {
                        states[index].isGranted = status == .authorizedAlways || status == .authorizedWhenInUse
                    }
                }
            }
            .onChange(of: currentIndex, { oldValue, newValue in
                guard states[newValue].isGranted == nil else { return }
                requestPermission(newValue)
            })
            .onAppear {
                showSheet = !isAllGranted
                if let firstRequestPermission = states.firstIndex(where: { $0.isGranted == nil }) {
                    requestPermission(firstRequestPermission)
                }
            }
    }
    
    @ViewBuilder
    private func permissionRow(_ state: PermissionState) -> some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(.gray, lineWidth: 1)
                
                Group {
                    if let isGranted = state.isGranted {
                        Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(isGranted ? .green : .red)
                    } else {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundStyle(.gray)
                    }
                }
                .font(.title3)
                .transition(.symbolEffect)
            }
            .frame(width: 22, height: 22)
            
            Text(state.id.rawValue)
                .font(.subheadline)
                .lineLimit(1)
        }
    }
    
    private func requestPermission(_ index: Int) {
        Task { @MainActor in
            let permission = states[index].id
            
            switch permission {
            case .location:
                locationManager.requestWhenInUseAuthorization()
            case .camera:
                let status = await AVCaptureDevice.requestAccess(for: .video)
                states[index].isGranted = status
            case .microphone:
                let status = await AVCaptureDevice.requestAccess(for: .audio)
                states[index].isGranted = status
            case .photoLibrary:
                let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                /// Limited is optional
                states[index].isGranted = (status == .authorized || status == .limited)
            }
            
            currentIndex = min(currentIndex + 1, states.count - 1)
        }
    }
    
    private var isThereAnyRejection: Bool {
        return states.contains(where: { $0.isGranted == false })
    }
    
    private var isAllGranted: Bool {
        states.filter {
            if let isGranted = $0.isGranted {
                return isGranted
            }
            return false
        }.count == states.count
    }
    
    private struct PermissionState: Identifiable {
        var id: Permission
        /// For Dynamic updates
        var isGranted: Bool?
        
        init(id: Permission) {
            self.id = id
            self.isGranted = id.isGranted
        }
    }
}

#Preview {
    ContentView()
}


@Observable
fileprivate class LocationManager: NSObject, CLLocationManagerDelegate {
    var status: CLAuthorizationStatus?
    var manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
    }
    
    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }
}
