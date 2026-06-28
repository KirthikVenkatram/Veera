import SwiftData
import SwiftUI

struct AddVowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title = ""
    @State private var vowBody = ""
    @State private var durationDays: Int = 30
    @State private var confirmationPresented = false

    private let durationOptions = [7, 30, 60, 90]
    private let bodyLimit = 500

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.obsidian.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        field(title: "TITLE") {
                            TextField("", text: $title, prompt: Text("Name your vow"))
                                .font(Fonts.bodyBold)
                                .foregroundStyle(Theme.parchment)
                        }
                        field(title: "BODY") {
                            TextField("", text: $vowBody, prompt: Text("What do you swear to?"), axis: .vertical)
                                .lineLimit(3...8)
                                .font(Fonts.body)
                                .foregroundStyle(Theme.parchment)
                                .onChange(of: vowBody) { _, newValue in
                                    if newValue.count > bodyLimit {
                                        vowBody = String(newValue.prefix(bodyLimit))
                                    }
                                }
                        }
                        field(title: "DURATION") {
                            Picker("", selection: $durationDays) {
                                ForEach(durationOptions, id: \.self) { value in
                                    Text("\(value)d").tag(value)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Vow")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Swear") { confirmationPresented = true }
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .tint(Theme.gold)
            .fullScreenCover(isPresented: $confirmationPresented) {
                VowSealingOverlay(title: trimmedTitle) {
                    saveVow()
                    confirmationPresented = false
                    dismiss()
                }
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveVow() {
        let vow = Vow(
            title: trimmedTitle,
            body: vowBody.trimmingCharacters(in: .whitespacesAndNewlines),
            durationDays: durationDays
        )
        context.insert(vow)
        try? context.save()
    }

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).labelStyle()
            content()
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.border, lineWidth: 1)
                )
        }
        .roundedCard()
        .padding(.vertical, 4)
    }
}

// MARK: - Sealing animation

private struct VowSealingOverlay: View {
    let title: String
    let onComplete: () -> Void

    @State private var stampScale: CGFloat = 0.2
    @State private var stampOpacity: Double = 0
    @State private var trim: CGFloat = 0
    @State private var titleOpacity: Double = 0

    var body: some View {
        ZStack {
            Theme.obsidian.opacity(0.97).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    Circle()
                        .trim(from: 0, to: trim)
                        .stroke(Theme.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .fill(Theme.gold.opacity(0.18))
                        .frame(width: 140, height: 140)
                        .scaleEffect(stampScale)
                        .opacity(stampOpacity)

                    Text("V")
                        .font(.system(size: 80, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.gold)
                        .scaleEffect(stampScale)
                        .opacity(stampOpacity)
                }
                .shadow(color: Theme.gold.opacity(0.45), radius: 30)

                VStack(spacing: 6) {
                    Text("VOW SWORN").labelStyle()
                    Text(title)
                        .font(Fonts.heading)
                        .tracking(3)
                        .foregroundStyle(Theme.gold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .opacity(titleOpacity)

                Spacer()
            }
        }
        .task {
            withAnimation(.easeInOut(duration: 0.6)) { trim = 1.0 }
            try? await Task.sleep(for: .milliseconds(400))
            HapticEngine.shared.vowSworn()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                stampScale = 1.0
                stampOpacity = 1.0
            }
            withAnimation(.easeIn(duration: 0.35).delay(0.15)) {
                titleOpacity = 1.0
            }
            try? await Task.sleep(for: .milliseconds(1400))
            onComplete()
        }
    }
}
