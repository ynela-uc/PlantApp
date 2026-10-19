import SwiftUI
import PhotosUI
import UIKit

enum ImageUtils {
    /// Turns a camera/gallery image into a smaller upright JPEG: respects the EXIF rotation,
    /// scales the longest side down to `maxSide`, and compresses. Keeps uploads and AI calls cheap and fast.
    static func prepareJpeg(_ raw: Data, maxSide: CGFloat = 1280, quality: CGFloat = 0.82) -> Data {
        guard let image = UIImage(data: raw) else { return raw }
        let size = image.size // already upright: UIKit applies the image orientation
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: quality) ?? raw
    }
}

/// Camera app wrapper (UIImagePickerController); hands back the raw JPEG bytes.
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImage: (Data) -> Void

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.95) {
                parent.onImage(data)
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

/// Adds the camera and photo-library sheets to a view. Set `camera` / `library` to true to open them.
private struct PhotoSheets: ViewModifier {
    @Binding var camera: Bool
    @Binding var library: Bool
    let onPhoto: (Data) -> Void
    @State private var item: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $camera) {
                CameraPicker(isPresented: $camera, onImage: onPhoto).ignoresSafeArea()
            }
            .photosPicker(isPresented: $library, selection: $item, matching: .images)
            .onChange(of: item) { newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) { onPhoto(data) }
                    item = nil
                }
            }
    }
}

extension View {
    func photoSheets(camera: Binding<Bool>, library: Binding<Bool>, onPhoto: @escaping (Data) -> Void) -> some View {
        modifier(PhotoSheets(camera: camera, library: library, onPhoto: onPhoto))
    }
}

/// "Take photo" opens the camera, or the library on devices without one (simulator).
func openCamera(camera: Binding<Bool>, library: Binding<Bool>) {
    if CameraPicker.isAvailable { camera.wrappedValue = true } else { library.wrappedValue = true }
}
