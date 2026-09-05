import SwiftUI

struct HomeView: View {
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showSettings = false
    @State private var buyerPriceText = ""

    @State private var isLoading = false
    @State private var profitResult: ProfitResult?
    @State private var errorMessage: String?

    private var buyerPrice: Double? {
        Double(buyerPriceText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    photoSection
                    priceSection
                    analyzeButton

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    }

                    if let profitResult {
                        ResultCardView(result: profitResult)
                    }
                }
                .padding()
            }
            .navigationTitle("ResaleProfit")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(source: .camera) { image in
                    capturedImage = image
                    profitResult = nil
                    errorMessage = nil
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoLibrary) {
                ImagePicker(source: .photoLibrary) { image in
                    capturedImage = image
                    profitResult = nil
                    errorMessage = nil
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var photoSection: some View {
        VStack(spacing: 12) {
            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 220)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.largeTitle)
                            Text("Take a photo of the item")
                        }
                        .foregroundStyle(.secondary)
                    }
            }

            HStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showPhotoLibrary = true
                } label: {
                    Label("Photo Library", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Seller's asking price")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text("$")
                TextField("0.00", text: $buyerPriceText)
                    .keyboardType(.decimalPad)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.1)))
        }
    }

    private var analyzeButton: some View {
        Button {
            analyze()
        } label: {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("Estimate Profit")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(capturedImage == nil || buyerPrice == nil || isLoading)
    }

    private func analyze() {
        guard let capturedImage, let buyerPrice else { return }
        errorMessage = nil
        profitResult = nil
        isLoading = true

        Task {
            do {
                let appraisal = try await AppraisalService().appraise(image: capturedImage)
                let result = await resolveProfitResult(appraisal: appraisal, buyerPrice: buyerPrice)
                await MainActor.run {
                    profitResult = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    /// Prefers a live average from eBay's Browse API; falls back to the
    /// AI's own estimate if no eBay keys are configured or the lookup fails.
    private func resolveProfitResult(appraisal: ItemAppraisal, buyerPrice: Double) async -> ProfitResult {
        do {
            let stats = try await EbayPricingService.shared.averagePrice(forQuery: appraisal.itemName)
            return ProfitResult(
                appraisal: appraisal,
                buyerAskingPrice: buyerPrice,
                averagePrice: stats.averagePrice,
                priceLow: stats.low,
                priceHigh: stats.high,
                priceSource: .ebayListings(count: stats.sampleSize)
            )
        } catch {
            return ProfitResult(appraisal: appraisal, buyerAskingPrice: buyerPrice)
        }
    }
}

#Preview {
    HomeView()
}
