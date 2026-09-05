import SwiftUI

struct ResultCardView: View {
    let result: ProfitResult

    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }

    private func format(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(result.appraisal.itemName)
                .font(.title3.bold())

            Text(result.appraisal.condition)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                labeledValue("Avg. Listing Price", format(result.averagePrice))
                Spacer()
                labeledValue("Asking Price", format(result.buyerAskingPrice))
            }

            Text("Range: \(format(result.priceLow)) - \(format(result.priceHigh)) - \(result.priceSource.label)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Estimated Profit")
                    .font(.headline)
                Spacer()
                Text((result.isProfitable ? "+" : "") + format(result.profit))
                    .font(.title2.bold())
                    .foregroundStyle(result.isProfitable ? .green : .red)
            }
            .padding(.top, 4)

            Text(result.appraisal.reasoning)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if case .aiEstimate = result.priceSource {
                Text("Estimate only, based on the model's general market knowledge. Add eBay developer keys in Settings for real listing prices.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.secondary.opacity(0.08)))
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}
