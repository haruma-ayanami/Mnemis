import SwiftUI

/// Итоги сессии: матрица результатов точками, точность, новые слова, время.
struct SessionSummaryView: View {
    let viewModel: LearnViewModel
    let onDone: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 9)

    var body: some View {
        ZStack(alignment: .top) {
            GlowHalo().frame(width: 360, height: 360).offset(y: -10)
            DotSphere(dotCount: 1500).frame(width: 200, height: 200).offset(y: 50)

            VStack(spacing: 0) {
                Spacer().frame(height: 250)
                VStack(spacing: 10) {
                    Text("[ session complete ]").bracketLabel(AppColor.accent)
                    Text("\(viewModel.reviewedCount) words, done.")
                        .font(.mnemisTitle).tracking(-0.8)
                        .foregroundStyle(AppColor.ink)
                    Text("streak is safe for today")
                        .font(.system(size: 15))
                        .foregroundStyle(AppColor.ash)
                }

                VStack(spacing: 16) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Array(viewModel.results.enumerated()), id: \.offset) { _, rating in
                            ResultDot(rating: rating)
                        }
                    }
                    HStack {
                        legend("● good \(count(.good))", AppColor.ink)
                        Spacer()
                        legend("● easy \(count(.easy))", AppColor.accent)
                        Spacer()
                        legend("● hard \(count(.hard))", AppColor.statusReviewing)
                        Spacer()
                        legend("○ again \(count(.again))", AppColor.smoke)
                    }
                }
                .padding(20)
                .glassCard()
                .padding(.top, 26)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Results"))
                .accessibilityValue(Text("\(count(.good)) good, \(count(.easy)) easy, \(count(.hard)) hard, \(count(.again)) again"))

                HStack(spacing: 10) {
                    StatTile(title: "accuracy", text: "\(viewModel.accuracyPercent)%")
                    StatTile(title: "new words", text: "+\(viewModel.newCount)")
                    StatTile(title: "minutes", text: viewModel.durationText)
                }
                .padding(.top, 12)

                Spacer()
                VStack(spacing: 10) {
                    Button(action: onDone) { Text("Done") }
                        .buttonStyle(PrimaryButtonStyle())
                    Button { viewModel.restart() } label: { Text("Learn 3 more new words") }
                        .buttonStyle(QuietButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private func count(_ rating: ReviewRating) -> Int {
        viewModel.results.filter { $0 == rating }.count
    }

    private func legend(_ text: String, _ color: Color) -> some View {
        Text(text).font(.system(size: 11, design: .monospaced)).foregroundStyle(color)
    }
}

private struct ResultDot: View {
    let rating: ReviewRating

    var body: some View {
        Group {
            switch rating {
            case .good: Circle().fill(AppColor.statusRemembered)
            case .easy: Circle().fill(AppColor.fill).shadow(color: AppColor.glow.opacity(0.7), radius: 5)
            case .hard: Circle().fill(AppColor.statusReviewing)
            case .again: Circle().stroke(AppColor.smoke, lineWidth: 1.5)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
