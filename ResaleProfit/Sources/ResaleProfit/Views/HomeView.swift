import SwiftUI

struct HomeView: View {
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showSettings = false
    @State private var buyerPriceText = ""

    @State private var isLoading = false
    @State private var appraisal: ItemAppraisal?
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

                    if let appraisal, let buyerPrice {
                        ResultCardView(
                            result: ProfitResult(appraisal: appraisal, buyerAskingPrice: buyerPrice)
                        )
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
                    appraisal = nil
                    errorMessage = nil
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoLibrary) {
                ImagePicker(source: .photoLibrary) { image in
                    capturedImage = image
                    appraisal = nil
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
        guard let capturedImage else { return }
        errorMessage = nil
        appraisal = nil
        isLoading = true

        Task {
            do {
                let result = try await AppraisalService().appraise(image: capturedImage)
                await MainActor.run {
                    appraisal = result
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
}

#Preview {
    HomeView()
}
