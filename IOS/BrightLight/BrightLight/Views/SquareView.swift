import SwiftUI

struct SquareView: View {
    let title: String
    var value: String?
    var imageName: String?
    var content: AnyView?

    init(title: String, value: String? = nil, imageName: String? = nil, content: AnyView? = nil) {
        self.title = title
        self.value = value
        self.imageName = imageName
        self.content = content
    }

    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
            if let imageName = imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
            }
            if let value = value {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
            }
            if let content = content {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.gray.opacity(0.5), radius: 5, x: 0, y: 2)
    }
}
