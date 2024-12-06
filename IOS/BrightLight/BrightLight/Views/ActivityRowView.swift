import SwiftUI

struct ActivityRowView: View {
    let activity: Activity
    let onComplete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(activity.title)
                    .font(.headline)
                    .strikethrough(activity.isCompleted)
                Text(activity.content)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .strikethrough(activity.isCompleted)
                Text("\(activity.duration) minutes")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            Spacer()
            Button(action: onComplete) {
                Image(systemName: activity.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(activity.isCompleted ? .green : .gray)
            }
        }
        .padding(.vertical, 5)
    }
}
