import SwiftUI

@MainActor
final class ScannerViewModel: ObservableObject {
    @Published var analysis: ProductAnalysis?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var scannedBarcode: String?

    func handleBarcode(_ code: String) {
        guard !isLoading else { return }
        scannedBarcode = code
        Task {
            await analyze(barcode: code)
        }
    }

    private func analyze(barcode: String) async {
        isLoading = true
        errorMessage = nil
        analysis = nil
        do {
            let response = try await APIClient.shared.fetchAnalysis(for: barcode)
            analysis = response
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func reset() {
        analysis = nil
        errorMessage = nil
        scannedBarcode = nil
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ScannerViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                BarcodeScannerView { barcode in
                    viewModel.handleBarcode(barcode)
                }

                overlayContent
            }
            .navigationTitle("Ingredient Scanner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Rescan") {
                        viewModel.reset()
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }

    @ViewBuilder
    private var overlayContent: some View {
        if viewModel.isLoading {
            ProgressView("Analyzing...")
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if let analysis = viewModel.analysis {
            AnalysisResultView(analysis: analysis, onDismiss: viewModel.reset)
                .transition(.move(edge: .bottom))
        } else if let errorMessage = viewModel.errorMessage {
            VStack(spacing: 12) {
                Text("Error")
                    .font(.headline)
                Text(errorMessage)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    viewModel.reset()
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

struct AnalysisResultView: View {
    let analysis: ProductAnalysis
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(analysis.productName)
                        .font(.title2.bold())
                    Text("Overall Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(analysis.overallScore)
                    .font(.largeTitle.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(scoreColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }

            Text("Ingredients")
                .font(.headline)

            ForEach(analysis.ingredients) { ingredient in
                IngredientRow(ingredient: ingredient)
            }

            Button(action: onDismiss) {
                Text("Scan Another")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding()
    }

    private var scoreColor: Color {
        switch analysis.overallScore.uppercased() {
        case "A":
            return .green
        case "B":
            return .blue
        case "C":
            return .yellow
        case "D":
            return .orange
        default:
            return .gray
        }
    }
}

struct IngredientRow: View {
    let ingredient: IngredientAnalysis

    private var riskColor: Color {
        switch ingredient.risk.lowercased() {
        case "high": return .red
        case "medium": return .orange
        default: return .green
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(riskColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(ingredient.name)
                        .font(.headline)
                    Spacer()
                    Text(ingredient.risk.capitalized)
                        .font(.subheadline)
                        .foregroundColor(riskColor)
                }
                Text(ingredient.details)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
