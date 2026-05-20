import SwiftUI
import UIKit
import Photos

// MARK: - Receipt Camera View
// 直接開啟相機；左下角有 ＋ 按鈕可改選相簿。
// 取得照片後呼叫 onImage callback，不自行儲存 Expense。

struct ReceiptCameraView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIViewController {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            let host = context.coordinator.makeLibraryHost(cancelClosesParent: true)
            context.coordinator.cameraVC = host
            return host
        }

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
        overlay.frame = vc.view.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        vc.cameraOverlayView = overlay

        return vc
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {}

    // MARK: Coordinator
    final class Coordinator: NSObject,
        UIImagePickerControllerDelegate,
        UINavigationControllerDelegate
    {
        let parent: ReceiptCameraView
        weak var cameraVC: UIViewController?

        init(parent: ReceiptCameraView) { self.parent = parent }

        // ＋ 按鈕 → 開相簿
        func openLibrary() {
            let host = makeLibraryHost(cancelClosesParent: false)
            host.modalPresentationStyle = .fullScreen
            cameraVC?.present(host, animated: true)
        }

        func makeLibraryHost(cancelClosesParent: Bool) -> UIViewController {
            let library = ReceiptPhotoLibraryView(
                onImage: { [weak self] image in
                    guard let self else { return }
                    if self.cameraVC?.presentedViewController != nil {
                        self.cameraVC?.dismiss(animated: true) {
                            self.finish(with: image)
                        }
                    } else {
                        self.finish(with: image)
                    }
                },
                onCancel: { [weak self] in
                    guard let self else { return }
                    if cancelClosesParent {
                        self.parent.isPresented = false
                    } else {
                        self.cameraVC?.dismiss(animated: true)
                    }
                }
            )
            return UIHostingController(rootView: library)
        }

        private func finish(with image: UIImage) {
            parent.isPresented = false
            parent.onImage(image)
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

// MARK: - Receipt Photo Library

private struct ReceiptPhotoLibraryView: View {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var assets: [PHAsset] = []
    @State private var selectedCategory: ReceiptAlbumCategory = .recents
    @State private var isLoading = true
    @State private var selectedAssetID: String?
    @State private var errorMessage: String?

    private var filteredAssets: [PHAsset] {
        assets.filter { selectedCategory.includes($0) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryPicker

                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.1)
                    Spacer()
                } else if !authorizationStatus.hasPhotoAccess {
                    photoPermissionView
                } else if filteredAssets.isEmpty {
                    emptyCategoryView
                } else {
                    photoGrid
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(selectedCategory.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
            }
            .alert("相簿更新失敗", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "請稍後再試。")
            }
        }
        .task {
            requestAccessAndLoad()
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ReceiptAlbumCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Label(category.title, systemImage: category.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(selectedCategory == category ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == category ? Color.accentColor : Color(.secondarySystemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
    }

    private var photoPermissionView: some View {
        ContentUnavailableView {
            Label("需要相簿權限", systemImage: "photo.on.rectangle")
        } description: {
            Text("請允許讀取與更新相簿，才能選取照片並切換喜愛項目。")
        } actions: {
            Button("開啟設定") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var emptyCategoryView: some View {
        ContentUnavailableView {
            Label("沒有項目", systemImage: selectedCategory.systemImage)
        } description: {
            Text(selectedCategory.emptyMessage)
        }
    }

    private var photoGrid: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 2
            let columnsCount = 3
            let itemSide = max(80, (geometry.size.width - CGFloat(columnsCount - 1) * spacing) / CGFloat(columnsCount))
            let columns = Array(repeating: GridItem(.fixed(itemSide), spacing: spacing), count: columnsCount)

            ScrollView {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(filteredAssets, id: \.localIdentifier) { asset in
                        ReceiptPhotoGridCell(
                            asset: asset,
                            side: itemSide,
                            isSelecting: selectedAssetID == asset.localIdentifier,
                            onSelect: { select(asset) },
                            onToggleFavorite: { toggleFavorite(asset) }
                        )
                    }
                }
            }
            .background(Color(.systemBackground))
        }
    }

    private func requestAccessAndLoad() {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if currentStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                Task { @MainActor in
                    authorizationStatus = status
                    loadAssets()
                }
            }
        } else {
            authorizationStatus = currentStatus
            loadAssets()
        }
    }

    private func loadAssets() {
        guard authorizationStatus.hasPhotoAccess else {
            assets = []
            isLoading = false
            return
        }

        isLoading = true
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(with: options)
        var loadedAssets: [PHAsset] = []
        loadedAssets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            loadedAssets.append(asset)
        }

        assets = loadedAssets
        isLoading = false
    }

    private func select(_ asset: PHAsset) {
        selectedAssetID = asset.localIdentifier

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isNetworkAccessAllowed = true

        var deliveredImage = false
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
            let isCancelled = (info?[PHImageCancelledKey] as? Bool) == true
            let hasError = info?[PHImageErrorKey] != nil

            guard !isDegraded, !isCancelled, !hasError, let image, !deliveredImage else {
                if isCancelled || hasError {
                    Task { @MainActor in selectedAssetID = nil }
                }
                return
            }

            deliveredImage = true
            Task { @MainActor in
                selectedAssetID = nil
                onImage(image)
            }
        }
    }

    private func toggleFavorite(_ asset: PHAsset) {
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = !asset.isFavorite
        } completionHandler: { success, error in
            Task { @MainActor in
                if success {
                    loadAssets()
                } else {
                    errorMessage = error?.localizedDescription ?? "無法更新喜愛項目。"
                }
            }
        }
    }
}

private enum ReceiptAlbumCategory: String, CaseIterable, Identifiable {
    case recents
    case screenshots
    case map
    case videos
    case favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recents: "最近項目"
        case .screenshots: "截圖"
        case .map: "地圖"
        case .videos: "影片"
        case .favorites: "喜愛項目"
        }
    }

    var systemImage: String {
        switch self {
        case .recents: "clock"
        case .screenshots: "camera.viewfinder"
        case .map: "map"
        case .videos: "video"
        case .favorites: "heart.fill"
        }
    }

    var emptyMessage: String {
        switch self {
        case .recents: "相簿中目前沒有可選取的項目。"
        case .screenshots: "目前沒有截圖。"
        case .map: "目前沒有包含位置資訊的照片或影片。"
        case .videos: "目前沒有影片。"
        case .favorites: "點一下照片右上角的愛心，就會出現在這裡。"
        }
    }

    func includes(_ asset: PHAsset) -> Bool {
        switch self {
        case .recents:
            true
        case .screenshots:
            asset.mediaType == .image && asset.mediaSubtypes.contains(.photoScreenshot)
        case .map:
            asset.location != nil
        case .videos:
            asset.mediaType == .video
        case .favorites:
            asset.isFavorite
        }
    }
}

private struct ReceiptPhotoGridCell: View {
    let asset: PHAsset
    let side: CGFloat
    let isSelecting: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ReceiptPhotoThumbnail(asset: asset, side: side)
                .frame(width: side, height: side)
                .contentShape(Rectangle())
                .onTapGesture(perform: onSelect)

            VStack {
                HStack(alignment: .top) {
                    Spacer()
                    Button(action: onToggleFavorite) {
                        Image(systemName: asset.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(asset.isFavorite ? .red : .white)
                            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                            .frame(width: 34, height: 34)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(asset.isFavorite ? "取消喜愛" : "加入喜愛")
                }

                Spacer()

                if asset.mediaType == .video {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.caption2.weight(.bold))
                        Text(Self.formatDuration(asset.duration))
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.65), radius: 2, x: 0, y: 1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(6)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.45)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }

            if isSelecting {
                Color.black.opacity(0.35)
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .background(Color(.secondarySystemBackground))
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct ReceiptPhotoThumbnail: View {
    let asset: PHAsset
    let side: CGFloat

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.tertiarySystemFill))
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .frame(width: side, height: side)
        .clipped()
        .onAppear(perform: requestThumbnail)
        .onDisappear(perform: cancelRequest)
    }

    private func requestThumbnail() {
        cancelRequest()

        let targetSize = CGSize(width: side * displayScale, height: side * displayScale)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true

        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { thumbnail, _ in
            guard let thumbnail else { return }
            Task { @MainActor in
                image = thumbnail
            }
        }
    }

    private func cancelRequest() {
        guard let requestID else { return }
        PHImageManager.default().cancelImageRequest(requestID)
        self.requestID = nil
    }
}

private extension PHAuthorizationStatus {
    var hasPhotoAccess: Bool {
        switch self {
        case .authorized, .limited:
            true
        case .denied, .notDetermined, .restricted:
            false
        @unknown default:
            false
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
