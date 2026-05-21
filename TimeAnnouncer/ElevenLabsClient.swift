import Foundation

enum ElevenLabsError: Error {
    case noApiKey
    case invalidResponse
    case httpError(statusCode: Int)
    case networkError(Error)
}

struct ElevenLabsClient {
    static let baseURL = "https://api.elevenlabs.io/v1"
    static let defaultVoiceId = "jqcCZkN6Knx8BJ5TBdYR" // Zara
    static let modelId = "eleven_flash_v2_5"

    static func fetchSpeech(text: String, voiceId: String = defaultVoiceId) async throws -> Data {
        guard let apiKey = KeychainHelper.load(forKey: "elevenlabs_api_key"), !apiKey.isEmpty else {
            throw ElevenLabsError.noApiKey
        }

        let url = URL(string: "\(baseURL)/text-to-speech/\(voiceId)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": text,
            "model_id": modelId,
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ElevenLabsError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw ElevenLabsError.httpError(statusCode: httpResponse.statusCode)
            }

            return data
        } catch let error as ElevenLabsError {
            throw error
        } catch {
            throw ElevenLabsError.networkError(error)
        }
    }
}
