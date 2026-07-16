import SwiftUI

struct PokemonDetailView: View {
    @ObservedObject var viewModel: PokemonDetailViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero
                detailContent
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(viewModel.summary.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            AsyncImage(url: viewModel.summary.artworkURL) { phase in
                if case .success(let image) = phase { image.resizable().scaledToFit() }
                else { Image(systemName: "questionmark.circle.fill").resizable().scaledToFit().padding(48).foregroundColor(.secondary) }
            }
            .frame(height: 220)
            Text(viewModel.summary.formattedID).font(.subheadline.monospacedDigit()).foregroundColor(.secondary)
            Text(viewModel.summary.displayName).font(.largeTitle.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder private var detailContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("Loading details…").padding(.vertical, 24)
        case .failure(let error, _):
            VStack(spacing: 12) {
                Text(error.localizedDescription).font(.footnote).foregroundColor(.secondary).multilineTextAlignment(.center)
                Button("Try Again") { Task { await viewModel.load() } }.buttonStyle(.borderedProminent)
            }.padding()
        case .success(let detail):
            VStack(spacing: 16) {
                section("Types") { tagList(detail.types) }
                section("About") {
                    infoRow("Height", detail.formattedHeight)
                    infoRow("Weight", detail.formattedWeight)
                    infoRow("Abilities", detail.abilities.map { $0.replacingOccurrences(of: "-", with: " ").capitalized }.joined(separator: ", "))
                }
                section("Base Stats") {
                    ForEach(detail.stats) { stat in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Text(stat.displayName).font(.caption); Spacer(); Text("\(stat.baseValue)").font(.caption.monospacedDigit()) }
                            ProgressView(value: min(Double(stat.baseValue), 255), total: 255).tint(.blue)
                        }
                    }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { Text(title).font(.headline); content() }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
    }
    private func tagList(_ values: [String]) -> some View { HStack { ForEach(values, id: \.self) { Text($0.capitalized).font(.subheadline.bold()).padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue.opacity(0.15)).clipShape(Capsule()) }; Spacer() } }
    private func infoRow(_ title: String, _ value: String) -> some View { HStack { Text(title).foregroundColor(.secondary); Spacer(); Text(value).multilineTextAlignment(.trailing) } }
}
