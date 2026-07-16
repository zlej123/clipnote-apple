import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.image")
                .font(.system(size: 44))
            Text("clipnote")
                .font(.largeTitle.bold())
            Text("영상을 문서로. 애매한 순간은 실제 화면으로.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
