import Foundation

struct ItemAppraisal: Codable {
    let itemName: String
    let condition: String
    let averagePriceLow: Double
    let averagePriceHigh: Double
    let reasoning: String

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

struct ProfitResult {
    let appraisal: ItemAppraisal
    let buyerAskingPrice: Double

    var profit: Double {
        appraisal.averagePrice - buyerAskingPrice
    }

    var isProfitable: Bool {
        profit > 0
    }
}
