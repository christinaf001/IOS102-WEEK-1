//
//  ContentView.swift
//  ScavangerHunt
//
//  Created by cecetoni on 9/23/25.
//

import SwiftUI
import UIKit
import MapKit
import CoreLocation

// MARK: - Task Model
struct Task: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    var isCompleted: Bool = false
    var photo: UIImage? = nil
    var location: CLLocationCoordinate2D? = nil
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last?.coordinate
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

// MARK: - ContentView (Task List)
struct ContentView: View {
    @State private var tasks = [
        Task(title: "Take a photo of a tree", description: "Find any tree nearby and take a photo"),
        Task(title: "Take a photo of a car", description: "Snap a photo of any parked car")
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach($tasks) { $task in
                    NavigationLink(destination: TaskDetailView(task: $task)) {
                        HStack {
                            Text(task.title)
                            Spacer()
                            if task.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scavenger Hunt")
        }
    }
}

// MARK: - Task Detail View
struct TaskDetailView: View {
    @Binding var task: Task
    @State private var showPicker = false
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary
    @ObservedObject var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    // Alert state
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            Text(task.title).font(.title).padding()
            Text(task.description).padding()

            if let image = task.photo {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)
                Text("✅ Completed").foregroundColor(.green).bold()
            } else {
                Text("❌ Not Completed").foregroundColor(.red).bold()
            }

            HStack {
                Button("Photo Library") {
                    pickerSource = .photoLibrary
                    showPicker = true
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                Button("Camera") {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        pickerSource = .camera
                        showPicker = true
                    } else {
                        alertMessage = "Camera not available on this device."
                        showAlert = true
                    }
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            // Map with safe annotation
            let tasksWithLocation = [task].filter { $0.location != nil }
            if !tasksWithLocation.isEmpty {
                Map(coordinateRegion: $region, annotationItems: tasksWithLocation) { t in
                    MapMarker(coordinate: t.location!, tint: .red)
                }
                .frame(height: 200)
                .cornerRadius(12)
            }

            Spacer()
        }
        .sheet(isPresented: $showPicker) {
            ImagePicker(image: $task.photo, sourceType: pickerSource)
                .onDisappear {
                    guard task.photo != nil else { return }
                    task.isCompleted = true

                    #if targetEnvironment(simulator)
                    // Simulator: assign a test location
                    task.location = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
                    region.center = task.location!
                    #else
                    // Real device: use actual location
                    if let currentLocation = locationManager.location {
                        task.location = currentLocation
                        region.center = currentLocation
                    } else {
                        print("⚠️ Current location not available yet")
                    }
                    #endif
                }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .padding()
        .navigationTitle("Task Detail")
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
