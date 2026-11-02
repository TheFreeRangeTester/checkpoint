import SwiftUI
import UIKit

struct CheckpointMemoryImage: View {
    let data: Data
    @State private var showingImage = false

    var body: some View {
        if let image = UIImage(data: data) {
            Button {
                showingImage = true
            } label: {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 190)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open checkpoint image")
            .sheet(isPresented: $showingImage) {
                NavigationStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.black)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingImage = false }
                            }
                        }
                }
            }
        }
    }
}
