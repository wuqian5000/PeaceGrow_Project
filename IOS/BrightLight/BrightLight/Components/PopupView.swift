import SwiftUI

struct PopupView: View {
    let message: String
    @Binding var isPresented: Bool

    var body: some View {
        VStack {
            Text(message)
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(radius: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .opacity(isPresented ? 1 : 0)
        .animation(.easeInOut, value: isPresented)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isPresented = false
            }
        }
    }
}
