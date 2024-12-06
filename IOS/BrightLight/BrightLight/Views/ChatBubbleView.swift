//
//  ChatBubbleView.swift
//  BrightLight
//
//  Created by 吴潜 on 2024/5/30.
//
import SwiftUI

struct ChatBubbleView: View {
    var message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            Text(message.text)
                .padding()
                .background(message.isUser ? Color.blue : Color.gray)
                .cornerRadius(10)
                .foregroundColor(.white)
            
            if !message.isUser {
                Spacer()
            }
        }
        .padding(message.isUser ? .leading : .trailing, 60)
    }
}
