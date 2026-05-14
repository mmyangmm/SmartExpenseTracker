import SwiftUI
import UIKit

// MARK: - Receipt Camera View
// 直接開啟相機；左下角有 ＋ 按鈕可改選相簿。
// 取得照片後呼叫 onImage callback，不自行儲存 Expense。

struct ReceiptCameraView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType    = .camera
        vc.allowsEditing = false
        vc.showsCameraControls = true
        vc.delegate = context.coordinator
        context.coordinator.cameraVC = vc

        // 透明 overlay：加 ＋ 按鈕
        let overlay = CameraLibraryOverlay {
            context.coordinator.openLibrary()
        }
        overlay.frame = UIScreen.main.bounds
        vc.cameraOverlayView = overlay

        return vc
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    // MARK: Coordinator
    final class Coordinator: NSObject,
        UIImagePickerControllerDelegate,
        UINavigationControllerDelegate
    {
        let parent: ReceiptCameraView
        weak var cameraVC: UIImagePickerController?

        init(parent: ReceiptCameraView) { self.parent = parent }

        // ＋ 按鈕 → 開相簿
        func openLibrary() {
            let picker = UIImagePickerController()
            picker.sourceType    = .photoLibrary
            picker.allowsEditing = false
            picker.delegate      = self
            cameraVC?.present(picker, animated: true)
        }

        // 照片選好 or 拍好
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            if let img = info[.originalImage] as? UIImage {
                parent.isPresented = false
                parent.onImage(img)
            }
        }

        // 取消
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            if picker.sourceType == .camera {
                parent.isPresented = false
            }
        }
    }
}

// MARK: - Camera Overlay（UIView）

final class CameraLibraryOverlay: UIView {
    private let onLibrary: () -> Void

    init(onLibrary: @escaping () -> Void) {
        self.onLibrary = onLibrary
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = true
        setupButton()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupButton() {
        let btn = UIButton(type: .custom)
        let cfg = UIImage.SymbolConfiguration(pointSize: 42, weight: .semibold)
        btn.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: cfg), for: .normal)
        btn.tintColor = .white
        btn.layer.shadowColor   = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.55
        btn.layer.shadowOffset  = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius  = 5
        btn.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        addSubview(btn)

        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 26),
            // 190pt 離底部：相機控制列約 120-140pt，確保出現在預覽區
            btn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -190)
        ])
    }

    @objc private func tapped() { onLibrary() }
}
