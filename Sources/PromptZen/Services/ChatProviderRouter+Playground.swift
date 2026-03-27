import Foundation

extension ChatProviderRouter {
    /// Builds the router for the selected Playground provider ([Ollama](https://ollama.com), [OpenRouter](https://openrouter.ai/docs/quickstart), [Gemini](https://ai.google.dev/gemini-api/docs/quickstart), [Groq](https://console.groq.com/docs/openai), [Mistral](https://docs.mistral.ai/api/), [Hugging Face Inference](https://huggingface.co/docs/inference-providers/en/guides/chat-completion), [Vercel AI Gateway](https://vercel.com/docs/ai-gateway), [OpenCode Zen](https://opencode.ai/docs/zen/), [Cerebras](https://inference-docs.cerebras.ai/), [Cohere](https://docs.cohere.com/v2/docs/chat-api), [GitHub Models](https://docs.github.com/en/github-models/quickstart), [Cloudflare Workers AI OpenAI compat](https://developers.cloudflare.com/workers-ai/configuration/open-ai-compatibility/), [NVIDIA NIM](https://docs.nvidia.com/nim/)).
    static func forPlayground(
        configuration c: PlaygroundChatConfiguration
    ) -> (router: ChatProviderRouter, phaseTimeouts: [TimeInterval], statusLine: String) {
        let standardPhases: [TimeInterval] = [30, 60]

        switch c.provider {
        case .ollama:
            return (
                ollamaCloudRotation(
                    baseURL: c.ollamaBaseURL,
                    apiKey: c.ollamaAPIKey,
                    preferredFirstModel: c.ollamaModel
                ),
                standardPhases,
                "Trying Ollama cloud models (30s per model, then 60s)…"
            )

        case .openRouter:
            var headers: [String: String] = [:]
            let ref = c.openRouterReferer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !ref.isEmpty { headers["HTTP-Referer"] = ref }
            let title = c.openRouterTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { headers["X-OpenRouter-Title"] = title }
            let p = OpenAICompatibleChatProvider(
                idPrefix: "openrouter",
                baseURLString: c.openRouterBaseURL,
                apiKey: c.openRouterAPIKey,
                model: c.openRouterModel,
                extraHTTPHeaders: headers
            )
            return (ChatProviderRouter(providers: [p]), standardPhases, "Calling OpenRouter…")

        case .googleGemini:
            let p = GeminiGoogleAIChatProvider(
                apiKey: c.geminiAPIKey,
                model: c.geminiModel,
                sortPriority: 0
            )
            return (ChatProviderRouter(providers: [p]), standardPhases, "Calling Google Gemini…")

        case .groq:
            let p = OpenAICompatibleChatProvider(
                idPrefix: "groq",
                baseURLString: "https://api.groq.com/openai/v1",
                apiKey: c.groqAPIKey,
                model: c.groqModel
            )
            return (ChatProviderRouter(providers: [p]), standardPhases, "Calling Groq…")

        case .mistral:
            let p = OpenAICompatibleChatProvider(
                idPrefix: "mistral",
                baseURLString: "https://api.mistral.ai/v1",
                apiKey: c.mistralAPIKey,
                model: c.mistralModel
            )
            return (ChatProviderRouter(providers: [p]), standardPhases, "Calling Mistral…")

        case .huggingFace:
            let p = OpenAICompatibleChatProvider(
                idPrefix: "huggingface",
                baseURLString: c.huggingFaceBaseURL,
                apiKey: c.huggingFaceAPIKey,
                model: c.huggingFaceModel
            )
            return (ChatProviderRouter(providers: [p]), standardPhases, "Calling Hugging Face…")

        case .vercelAIGateway:
            let p = OpenAICompatibleChatProvider(
                idPrefix: "vercel-ai-gateway",
                baseURLString: "https://ai-gateway.vercel.sh/v1",
                apiKey: c.vercelAIGatewayAPIKey,
                model: c.vercelAIGatewayModel
            )
            return (ChatProviderRouter(providers: [p]), standardPhases, "Calling Vercel AI Gateway…")

        case .openCodeZen:
            let p = OpenAICompatibleChatProvider(
                idPrefix: "opencode-zen",
                baseURLString: "https://opencode.ai/zen/v1",
                apiKey: c.openCodeZenAPIKey,
                model: c.openCodeZenModel
            )
            return (ChatProviderRouter(providers: [p]), standardPhases, "Calling OpenCode Zen…")

        case .cerebras:
            let p = OpenAICompatibleChatProvider(
                idPrefix: "cerebras",
                baseURLString: "https://api.cerebras.ai/v1",
                apiKey: c.cerebrasAPIKey,
                model: c.cerebrasModel
            )
            return (ChatProviderRouter(providers: [p]), standardPhases, "Calling Cerebras…")

        case .cohere:
            let p = CohereV2ChatProvider(
                apiKey: c.cohereAPIKey,
                model: c.cohereModel,
                sortPriority: 0
            )
            return (ChatProviderRouter(providers: [p]), standardPhases, "Calling Cohere…")

        case .githubModels:
            let p = OpenAICompatibleChatProvider(
                idPrefix: "github-models",
                baseURLString: "https://models.github.ai/inference/chat/completions",
                apiKey: c.githubModelsToken,
                model: c.githubModelsModel,
                extraHTTPHeaders: [
                    "Accept": "application/vnd.github+json",
                    "X-GitHub-Api-Version": "2022-11-28",
                ]
            )
            return (ChatProviderRouter(providers: [p]), standardPhases, "Calling GitHub Models…")

        case .cloudflareWorkersAI:
            let account = c.cloudflareAccountId.trimmingCharacters(in: .whitespacesAndNewlines)
            let base = "https://api.cloudflare.com/client/v4/accounts/\(account)/ai/v1"
            let p = OpenAICompatibleChatProvider(
                idPrefix: "cloudflare-workers-ai",
                baseURLString: base,
                apiKey: c.cloudflareAPIToken,
                model: c.cloudflareModel
            )
            return (ChatProviderRouter(providers: [p]), standardPhases, "Calling Cloudflare Workers AI…")

        case .nvidiaNIM:
            let p = OpenAICompatibleChatProvider(
                idPrefix: "nvidia-nim",
                baseURLString: c.nvidiaNIMBaseURL,
                apiKey: c.nvidiaNIMAPIKey,
                model: c.nvidiaNIMModel
            )
            return (ChatProviderRouter(providers: [p]), standardPhases, "Calling NVIDIA NIM…")
        }
    }
}
