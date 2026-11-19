import SwiftUI

struct UserAvatarView: View {
    var avatarUrl: String? = nil
    var uiImage: UIImage? = nil
    var name: String = ""
    var size: CGFloat = 64
    var showBorder: Bool = true

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "U" : String(trimmed.prefix(1)).uppercased()
    }

    private var base64Image: UIImage? {
        guard let urlStr = avatarUrl, urlStr.hasPrefix("data:image") else { return nil }
        if let commaIndex = urlStr.firstIndex(of: ",") {
            let base64 = String(urlStr[urlStr.index(after: commaIndex)...])
            if let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) {
                return UIImage(data: data)
            }
        }
        return nil
    }

    var body: some View {
        ZStack {
            if let image = uiImage ?? base64Image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let urlStr = avatarUrl,
                      let url = URL(string: urlStr),
                      !urlStr.hasPrefix("data:image") {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure, .empty:
                        fallbackMonogram
                    @unknown default:
                        fallbackMonogram
                    }
                }
            } else {
                fallbackMonogram
            }
        }
        .frame(width: size, height: size)
        .overlay {
            if showBorder {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.emerald.opacity(0.7), Color.emerald.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(2, size / 28)
                    )
            }
        }
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
    }

    private var fallbackMonogram: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.emerald.opacity(0.22), Color.emerald.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(initial)
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundStyle(Color.emerald)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - UIImage Resize Helper
extension UIImage {
    func resized(toMaxDimension maxDim: CGFloat) -> UIImage {
        let currentWidth = size.width
        let currentHeight = size.height
        if currentWidth <= maxDim && currentHeight <= maxDim {
            return self
        }

        let ratio = currentWidth / currentHeight
        var newSize: CGSize
        if currentWidth > currentHeight {
            newSize = CGSize(width: maxDim, height: maxDim / ratio)
        } else {
            newSize = CGSize(width: maxDim * ratio, height: maxDim)
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
