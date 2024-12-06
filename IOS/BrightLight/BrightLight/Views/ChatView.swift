import SwiftUI

struct ChatView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var messageText: String = ""

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(viewModel.messages, id: \.id) { message in
                        HStack(alignment: .bottom, spacing: 8) {
                            if message.isUser {
                                Spacer()
                                Text(message.text)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                            } else {
                                Image("chatbot_profile_image")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                    .padding(.leading, 8)

                                Text(message.text)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.black)
                                    .cornerRadius(10)
                                    .padding(.trailing, 8)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            HStack {
                TextField("Enter message", text: $messageText)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .frame(minHeight: 40)

                Button(action: {
                    viewModel.sendMessage(messageText)
                    messageText = ""
                }) {
                    Image(systemName: "paperplane.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .padding(8)
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
            .environmentObject(ChatViewModel())
    }
}
