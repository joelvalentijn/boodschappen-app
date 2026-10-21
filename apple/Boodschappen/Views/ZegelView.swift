import SwiftUI

/// Groot scherm voor aan de kassa, met voorleesknop.
struct ZegelView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var speaker = Speaker()

    private let message = "Ik wil graag zegeltjes alstublieft"

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 0)
                Text(message)
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(Color(red: 0.45, green: 0.30, blue: 0.0))
                    .padding(28)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.97, blue: 0.90), Color(red: 1.0, green: 0.92, blue: 0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                    )
                Text("Laat dit scherm aan de kassa zien, of laat het voorlezen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
                Button {
                    speaker.speak(message)
                } label: {
                    Label("Voorlezen", systemImage: "speaker.wave.2.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
            .padding(24)
            .navigationTitle("Zegeltjes")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluit") { dismiss() }
                }
            }
        }
        .onDisappear { speaker.stop() }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 500)
        #endif
    }
}
