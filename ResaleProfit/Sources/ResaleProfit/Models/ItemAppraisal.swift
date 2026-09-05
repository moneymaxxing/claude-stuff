import Foundation

struct ItemAppraisal: Codable {
    let itemName: String
    let condition: String
    let averagePriceLow: Double
    let averagePriceHigh: Double
    let reasoning: String

    /// Fallback estimate when no eBay listings are available.
    var averagePrice: Double {
        (averagePriceLow + averagePriceHigh) / 2
    }

    enum CodingKeys: String, CodingKey {
        case itemName = "item_name"
        case condition
        case averagePriceLow = "average_price_low"
        case averagePriceHigh = "average_price_high"
        case reasoning
    }
}

enum PriceSource {
    case ebayListings(count: Int)
    case aiEstimate

    var label: String {
        switch self {
        case .ebayListings(let count):
            return "eBay - \(count) active listing\(count == 1 ? "" : "s")"
        case .aiEstimate:
            return "AI estimate (no eBay keys configured)"
        }
    }
}

struct ProfitResult {
    let appraisal: ItemAppraisal
    let buyerAskingPrice: Double
    let averagePrice: Double
    let priceLow: Double
    let priceHigh: Double
    let priceSource: PriceSource

    var profit: Double {
        averagePrice - buyerAskingPrice
    }

    var isProfitable: Bool {
        profit > 0
    }

    /// Uses the appraisal's own low/high estimate unless real eBay data
    /// overrides it.
    init(
        appraisal: ItemAppraisal,
        buyerAskingPrice: Double,
        averagePrice: Double? = nil,
        priceLow: Double? = nil,
        priceHigh: Double? = nil,
        priceSource: PriceSource = .aiEstimate
    ) {
        self.appraisal = appraisal
        self.buyerAskingPrice = buyerAskingPrice
        self.averagePrice = averagePrice ?? appraisal.averagePrice
        self.priceLow = priceLow ?? appraisal.averagePriceLow
        self.priceHigh = priceHigh ?? appraisal.averagePriceHigh
        self.priceSource = priceSource
    }
}
