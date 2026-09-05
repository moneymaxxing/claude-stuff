import Foundation

struct EbayPriceStats {
    let averagePrice: Double
    let low: Double
    let high: Double
    let currency: String
    let sampleSize: Int
}

enum EbayPricingError: LocalizedError {
    case missingCredentials
    case authFailed(String)
    case searchFailed(String)
    case noListingsFound

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Add eBay developer keys in Settings to pull real listing prices."
        case .authFailed(let message):
            return "eBay authentication failed: \(message)"
        case .searchFailed(let message):
            return "eBay search failed: \(message)"
        case .noListingsFound:
            return "No comparable eBay listings were found for this item."
        }
    }
}

/// Looks up the average *current* listing price for an item using eBay's
/// Browse API (public, OAuth client-credentials access). eBay's sold/
/// completed-listings data (Marketplace Insights API) requires a separate,
/// restricted partner application, so this uses active listings as the
/// market comparison instead - which is what the app labels as
/// "Avg. Listing Price".
actor EbayPricingService {
    static let shared = EbayPricingService()

    private var cachedToken: String?
    private var tokenExpiry: Date?

    private let tokenURL = URL(string: "https://api.ebay.com/identity/v1/oauth2/token")!
    private let searchURL = URL(string: "https://api.ebay.com/buy/browse/v1/item_summary/search")!

    func averagePrice(forQuery query: String, maxResults: Int = 25) async throws -> EbayPriceStats {
        guard let credentials = KeychainService.loadEbayCredentials() else {
            throw EbayPricingError.missingCredentials
        }

        let token = try await accessToken(appID: credentials.appID, certID: credentials.certID)
        let prices = try await searchItemPrices(query: query, token: token, limit: maxResults)

        guard !prices.isEmpty else {
            throw EbayPricingError.noListingsFound
        }

        let sorted = prices.map(\.value).sorted()
        let average = sorted.reduce(0, +) / Double(sorted.count)
        return EbayPriceStats(
            averagePrice: average,
            low: sorted.first ?? average,
            high: sorted.last ?? average,
            currency: prices.first?.currency ?? "USD",
            sampleSize: sorted.count
        )
    }

    // MARK: - OAuth (client credentials grant)

    private func accessToken(appID: String, certID: String) async throws -> String {
        if let cachedToken, let tokenExpiry, tokenExpiry > Date() {
            return cachedToken
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let credentials = "\(appID):\(certID)"
        guard let credentialsData = credentials.data(using: .utf8) else {
            throw EbayPricingError.authFailed("Could not encode credentials.")
        }
        let basicAuth = credentialsData.base64EncodedString()
        request.setValue("Basic \(basicAuth)", forHTTPHeaderField: "Authorization")

        let bodyParams = "grant_type=client_credentials&scope=https://api.ebay.com/oauth/api_scope"
        request.httpBody = Data(bodyParams.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw EbayPricingError.authFailed(message)
        }

        struct TokenResponse: Decodable {
            let access_token: String
            let expires_in: Int
        }

        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        cachedToken = decoded.access_token
        tokenExpiry = Date().addingTimeInterval(TimeInterval(decoded.expires_in - 60))
        return decoded.access_token
    }

    // MARK: - Browse API search

    private struct PricePoint {
        let value: Double
        let currency: String
    }

    private func searchItemPrices(query: String, token: String, limit: Int) async throws -> [PricePoint] {
        var components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "filter", value: "buyingOptions:{FIXED_PRICE}")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("EBAY_US", forHTTPHeaderField: "X-EBAY-C-MARKETPLACE-ID")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw EbayPricingError.searchFailed(message)
        }

        struct SearchResponse: Decodable {
            struct Item: Decodable {
                struct Price: Decodable {
                    let value: String
                    let currency: String
                }
                let price: Price?
            }
            let itemSummaries: [Item]?
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        return (decoded.itemSummaries ?? []).compactMap { item in
            guard let price = item.price, let value = Double(price.value) else { return nil }
            return PricePoint(value: value, currency: price.currency)
        }
    }
}
