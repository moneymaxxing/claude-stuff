import Foundation
import UIKit

enum AppraisalError: LocalizedError {
    case missingAPIKey
    case imageEncodingFailed
    case invalidResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your Anthropic API key in Settings before analyzing an item."
        case .imageEncodingFailed:
            return "Couldn't process that photo. Try taking it again."
        case .invalidResponse:
            return "The model's response couldn't be understood. Try again."
        case .api(let message):
            return message
        }
    }
}

/// Calls the Claude API (vision) to identify a photographed item and estimate
/// its average resale/listing price. This is a market estimate from the
/// model's general knowledge, not a live marketplace lookup.
struct AppraisalService {
    private let model = "claude-sonnet-5"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func appraise(image: UIImage) async throws -> ItemAppraisal {
        guard let apiKey = KeychainService.loadAPIKey(), !apiKey.isEmpty else {
            throw AppraisalError.missingAPIKey
        }
        guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
            throw AppraisalError.imageEncodingFailed
        }
        let base64Image = jpegData.base64EncodedString()

        let prompt = """
        You are appraising a secondhand item from a photo for someone deciding \
        whether to buy it for resale. Identify the item as specifically as you \
        can (brand, model, category) from the image. Then estimate the average \
        price it typically resells for in used/secondhand marketplaces (e.g. \
        eBay sold listings, Facebook Marketplace, Poshmark, StockX - whichever \
        fits the category), based on your general knowledge. Give a realistic \
        low and high estimate for its apparent condition.

        Respond with ONLY a JSON object, no other text, matching this schema:
        {
          "item_name": string,
          "condition": string (brief condition assessment from the photo),
          "average_price_low": number (USD),
          "average_price_high": number (USD),
          "reasoning": string (1-2 sentences on how you arrived at the estimate)
        }
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "type": "text",
                            "text": prompt
                        ]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppraisalError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let apiMessage = ((message?["error"] as? [String: Any])?["message"] as? String)
                ?? "Request failed (\(httpResponse.statusCode))."
            throw AppraisalError.api(apiMessage)
        }

        return try parseAppraisal(from: data)
    }

    private func parseAppraisal(from data: Data) throws -> ItemAppraisal {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let text = content.first(where: { $0["type"] as? String == "text" })?["text"] as? String
        else {
            throw AppraisalError.invalidResponse
        }

        guard let jsonText = extractJSONObject(from: text) else {
            throw AppraisalError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ItemAppraisal.self, from: Data(jsonText.utf8))
    }

    /// The model is asked to reply with only JSON, but strips fenced code
    /// blocks or stray text defensively before decoding.
    private func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            return nil
        }
        return String(text[start...end])
    }
}
