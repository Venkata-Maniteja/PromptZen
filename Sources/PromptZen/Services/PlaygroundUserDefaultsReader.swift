import Foundation

/// Reads the same `UserDefaults` keys as `PlaygroundView` so the tunnel `/chat` handler uses the current provider settings.
enum PlaygroundUserDefaultsReader {
    private static let env = ProcessInfo.processInfo.environment

    static func loadChatConfiguration() -> PlaygroundChatConfiguration {
        let defaults = UserDefaults.standard
        let providerRaw = defaults.string(forKey: "PromptZen.playgroundProvider") ?? PlaygroundAIProviderKind.ollama.rawValue
        let provider = PlaygroundAIProviderKind(rawValue: providerRaw) ?? .ollama

        func s(_ key: String, default def: String = "") -> String {
            defaults.string(forKey: key) ?? def
        }

        func keyOrEnv(storedKey: String, envKeys: [String]) -> String {
            let stored = s(storedKey).trimmingCharacters(in: .whitespacesAndNewlines)
            if !stored.isEmpty { return stored }
            for k in envKeys {
                if let v = env[k]?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty { return v }
            }
            return ""
        }

        return PlaygroundChatConfiguration(
            provider: provider,
            ollamaBaseURL: s("PromptZen.ollamaBaseURL", default: "https://ollama.com"),
            ollamaModel: s("PromptZen.ollamaModel", default: "deepseek-v3.1:latest"),
            ollamaAPIKey: keyOrEnv(storedKey: "PromptZen.ollamaAPIKey", envKeys: ["OLLAMA_API_KEY"]),
            openRouterBaseURL: s("PromptZen.openRouterBaseURL", default: "https://openrouter.ai/api/v1"),
            openRouterModel: s("PromptZen.openRouterModel", default: "openai/gpt-4o-mini"),
            openRouterAPIKey: keyOrEnv(storedKey: "PromptZen.openRouterAPIKey", envKeys: ["OPENROUTER_API_KEY"]),
            openRouterReferer: s("PromptZen.openRouterReferer"),
            openRouterTitle: s("PromptZen.openRouterTitle", default: "PromptZen"),
            geminiAPIKey: {
                let a = s("PromptZen.geminiAPIKey")
                if !a.isEmpty { return a }
                return env["GEMINI_API_KEY"] ?? env["GOOGLE_API_KEY"] ?? ""
            }(),
            geminiModel: s("PromptZen.geminiModel", default: "gemini-2.5-flash"),
            groqAPIKey: keyOrEnv(storedKey: "PromptZen.groqAPIKey", envKeys: ["GROQ_API_KEY"]),
            groqModel: s("PromptZen.groqModel", default: "llama-3.3-70b-versatile"),
            mistralAPIKey: keyOrEnv(storedKey: "PromptZen.mistralAPIKey", envKeys: ["MISTRAL_API_KEY"]),
            mistralModel: s("PromptZen.mistralModel", default: "mistral-small-latest"),
            huggingFaceAPIKey: keyOrEnv(storedKey: "PromptZen.huggingFaceAPIKey", envKeys: ["HF_TOKEN", "HUGGING_FACE_HUB_TOKEN"]),
            huggingFaceBaseURL: s("PromptZen.huggingFaceBaseURL", default: "https://router.huggingface.co/v1"),
            huggingFaceModel: s("PromptZen.huggingFaceModel", default: "meta-llama/Llama-3.2-3B-Instruct"),
            vercelAIGatewayAPIKey: keyOrEnv(storedKey: "PromptZen.vercelAIGatewayAPIKey", envKeys: ["VERCEL_AI_GATEWAY_KEY", "AI_GATEWAY_API_KEY"]),
            vercelAIGatewayModel: s("PromptZen.vercelAIGatewayModel", default: "openai/gpt-4o-mini"),
            openCodeZenAPIKey: keyOrEnv(storedKey: "PromptZen.openCodeZenAPIKey", envKeys: ["OPENCODE_API_KEY"]),
            openCodeZenModel: s("PromptZen.openCodeZenModel", default: "minimax-m2.5-free"),
            cerebrasAPIKey: keyOrEnv(storedKey: "PromptZen.cerebrasAPIKey", envKeys: ["CEREBRAS_API_KEY"]),
            cerebrasModel: s("PromptZen.cerebrasModel", default: "llama3.1-8b"),
            cohereAPIKey: keyOrEnv(storedKey: "PromptZen.cohereAPIKey", envKeys: ["COHERE_API_KEY"]),
            cohereModel: s("PromptZen.cohereModel", default: "command-r-plus-08-2024"),
            githubModelsToken: {
                let t = s("PromptZen.githubModelsToken")
                if !t.isEmpty { return t }
                return env["GITHUB_MODELS_TOKEN"] ?? env["GITHUB_TOKEN"] ?? ""
            }(),
            githubModelsModel: s("PromptZen.githubModelsModel", default: "openai/gpt-4o-mini"),
            cloudflareAccountId: {
                let a = s("PromptZen.cloudflareAccountId")
                if !a.isEmpty { return a }
                return env["CLOUDFLARE_ACCOUNT_ID"] ?? ""
            }(),
            cloudflareAPIToken: keyOrEnv(storedKey: "PromptZen.cloudflareAPIToken", envKeys: ["CLOUDFLARE_API_TOKEN"]),
            cloudflareModel: s("PromptZen.cloudflareModel", default: "@cf/meta/llama-3.1-8b-instruct"),
            nvidiaNIMBaseURL: s("PromptZen.nvidiaNIMBaseURL", default: "https://integrate.api.nvidia.com/v1"),
            nvidiaNIMAPIKey: keyOrEnv(storedKey: "PromptZen.nvidiaNIMAPIKey", envKeys: ["NVIDIA_API_KEY"]),
            nvidiaNIMModel: s("PromptZen.nvidiaNIMModel", default: "meta/llama-3.1-8b-instruct")
        )
    }
}
