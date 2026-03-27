import Foundation

/// Snapshot of Playground settings for one Run (from [free LLM API resources](https://github.com/cheahjs/free-llm-api-resources) style providers).
struct PlaygroundChatConfiguration: Sendable {
    var provider: PlaygroundAIProviderKind

    var ollamaBaseURL: String
    var ollamaModel: String
    var ollamaAPIKey: String

    var openRouterBaseURL: String
    var openRouterModel: String
    var openRouterAPIKey: String
    var openRouterReferer: String
    var openRouterTitle: String

    var geminiAPIKey: String
    var geminiModel: String

    var groqAPIKey: String
    var groqModel: String

    var mistralAPIKey: String
    var mistralModel: String

    var huggingFaceAPIKey: String
    var huggingFaceBaseURL: String
    var huggingFaceModel: String

    var vercelAIGatewayAPIKey: String
    var vercelAIGatewayModel: String

    var openCodeZenAPIKey: String
    var openCodeZenModel: String

    var cerebrasAPIKey: String
    var cerebrasModel: String

    var cohereAPIKey: String
    var cohereModel: String

    var githubModelsToken: String
    var githubModelsModel: String

    var cloudflareAccountId: String
    var cloudflareAPIToken: String
    var cloudflareModel: String

    var nvidiaNIMBaseURL: String
    var nvidiaNIMAPIKey: String
    var nvidiaNIMModel: String
}
