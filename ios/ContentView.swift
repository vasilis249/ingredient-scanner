import SwiftUI

@MainActor
final class CosmeticScannerViewModel: ObservableObject {
    @Published var analysis: ProductAnalysisResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isShowingScanner: Bool = false
    @Published var lastScannedCode: String?

    func startScanning() {
        errorMessage = nil
        isShowingScanner = true
    }

    func handleBarcode(_ code: String) {
        isShowingScanner = false
        lastScannedCode = code
        Task { await analyze(barcode: code) }
    }

    private func analyze(barcode: String) async {
        isLoading = true
        errorMessage = nil
        analysis = nil
        do {
            let response = try await APIClient.shared.analyzeCosmetic(barcode: barcode)
            analysis = response
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func reset() {
        analysis = nil
        errorMessage = nil
        lastScannedCode = nil
    }
}

struct ContentView: View {
    @StateObject private var viewModel = CosmeticScannerViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Scan cosmetic products and get ingredient risk insights.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Button(action: viewModel.startScanning) {
                    HStack {
                        Image(systemName: "barcode.viewfinder")
                        Text("Scan cosmetic product")
                            .bold()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal)
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.6 : 1)

                if viewModel.isLoading {
                    VStack(spacing: 8) {
                        ProgressView("Analyzing...")
                        if let code = viewModel.lastScannedCode {
                            Text("Barcode: \(code)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .progressViewStyle(.circular)
                    .padding()
                }

                if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 8) {
                        Label("Error", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                        HStack {
                            Button("Dismiss") { viewModel.reset() }
                            Spacer()
                            Button("Scan again") {
                                viewModel.reset()
                                viewModel.startScanning()
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal)
                }

                if let analysis = viewModel.analysis {
                    AnalysisResultView(analysis: analysis, onDismiss: viewModel.reset)
                        .transition(.opacity)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Cosmetic Scanner")
            .sheet(isPresented: $viewModel.isShowingScanner) {
                BarcodeScannerView { barcode in
                    viewModel.handleBarcode(barcode)
                }
            }
        }
    }
}

struct AnalysisResultView: View {
    let analysis: ProductAnalysisResponse
    let onDismiss: () -> Void

    private var scoreColor: Color {
        switch analysis.overallScore.uppercased() {
        case "A": return .green
        case "B": return .blue
        case "C": return .orange
        case "D": return .red
        default: return .gray
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(analysis.productName)
                            .font(.title2.bold())
                        Text("Barcode: \(analysis.barcode)")
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
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Overall summary")
                        .font(.headline)
                    Text(analysis.overallSummary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Ingredients")
                        .font(.headline)
                    ForEach(analysis.ingredients) { ingredient in
                        IngredientRow(ingredient: ingredient)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Disclaimer")
                        .font(.headline)
                    Text(analysis.disclaimer)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Button(action: onDismiss) {
                    Text("Scan another product")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding()
        }
    }
}

struct IngredientRow: View {
    let ingredient: IngredientRisk

    private var riskColor: Color {
        switch ingredient.riskLevel.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Circle()
                    .fill(riskColor)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(ingredient.inciName)
                            .font(.headline)
                        Spacer()
                        Text(ingredient.riskLevel.capitalized)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(riskColor)
                    }
                    Text(ingredient.function.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !ingredient.concerns.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Concerns")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    ForEach(ingredient.concerns, id: \.self) { concern in
                        Text("• \(concern)")
                            .font(.caption)
                    }
                }
            }

            Text(ingredient.aiSummary)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
