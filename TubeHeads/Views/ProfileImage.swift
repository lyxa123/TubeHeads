import SwiftUI

struct UserProfileImageView: View {
    let size: CGFloat
    let image: UIImage?
    
    init(size: CGFloat, image: UIImage? = nil) {
        self.size = size
        self.image = image
    }
    
    var body: some View {
        if let uiImage = image {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                .shadow(radius: 1)
        } else {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: size / 2.5))
                )
                .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
        }
    }
} 