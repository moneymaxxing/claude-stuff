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
                labeledValue("Avg. Listing Price", format(result.appraisal.averagePrice))
                Spacer()
                labeledValue("Asking Price", format(result.buyerAskingPrice))
            }

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

            Text("Estimate only, based on the model's general market knowledge - not a live marketplace lookup.")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
