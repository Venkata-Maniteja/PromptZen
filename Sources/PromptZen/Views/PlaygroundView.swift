import AppKit
import SwiftUI

/// Playground: [free LLM APIs](https://github.com/cheahjs/free-llm-api-resources) + Ollama. Each provider’s docs differ—see sidebar hints.
struct PlaygroundView: View {
    @AppStorage("PromptZen.playgroundProvider") private var playgroundProviderRaw: String = PlaygroundAIProviderKind.ollama.rawValue

    @AppStorage("PromptZen.ollamaBaseURL") private var ollamaBaseURL: String = "https://ollama.com"
    @AppStorage("PromptZen.ollamaModel") private var ollamaModel: String = "deepseek-v3.1:latest"
    @AppStorage("PromptZen.ollamaAPIKey") private var ollamaAPIKey: String = ""

    @AppStorage("PromptZen.openRouterBaseURL") private var openRouterBaseURL: String = "https://openrouter.ai/api/v1"
    @AppStorage("PromptZen.openRouterModel") private var openRouterModel: String = "openai/gpt-4o-mini"
    @AppStorage("PromptZen.openRouterAPIKey") private var openRouterAPIKey: String = ""
    @AppStorage("PromptZen.openRouterReferer") private var openRouterReferer: String = ""
    @AppStorage("PromptZen.openRouterTitle") private var openRouterTitle: String = "PromptZen"

    @AppStorage("PromptZen.geminiAPIKey") private var geminiAPIKey: String = ""
    @AppStorage("PromptZen.geminiModel") private var geminiModel: String = "gemini-2.5-flash"

    @AppStorage("PromptZen.groqAPIKey") private var groqAPIKey: String = ""
    @AppStorage("PromptZen.groqModel") private var groqModel: String = "llama-3.3-70b-versatile"

    @AppStorage("PromptZen.mistralAPIKey") private var mistralAPIKey: String = ""
    @AppStorage("PromptZen.mistralModel") private var mistralModel: String = "mistral-small-latest"

    @AppStorage("PromptZen.huggingFaceAPIKey") private var huggingFaceAPIKey: String = ""
    @AppStorage("PromptZen.huggingFaceBaseURL") private var huggingFaceBaseURL: String = "https://router.huggingface.co/v1"
    @AppStorage("PromptZen.huggingFaceModel") private var huggingFaceModel: String = "meta-llama/Llama-3.2-3B-Instruct"

    @AppStorage("PromptZen.vercelAIGatewayAPIKey") private var vercelAIGatewayAPIKey: String = ""
    @AppStorage("PromptZen.vercelAIGatewayModel") private var vercelAIGatewayModel: String = "openai/gpt-4o-mini"

    @AppStorage("PromptZen.openCodeZenAPIKey") private var openCodeZenAPIKey: String = ""
    @AppStorage("PromptZen.openCodeZenModel") private var openCodeZenModel: String = "minimax-m2.5-free"

    @AppStorage("PromptZen.cerebrasAPIKey") private var cerebrasAPIKey: String = ""
    @AppStorage("PromptZen.cerebrasModel") private var cerebrasModel: String = "llama3.1-8b"

    @AppStorage("PromptZen.cohereAPIKey") private var cohereAPIKey: String = ""
    @AppStorage("PromptZen.cohereModel") private var cohereModel: String = "command-r-plus-08-2024"

    @AppStorage("PromptZen.githubModelsToken") private var githubModelsToken: String = ""
    @AppStorage("PromptZen.githubModelsModel") private var githubModelsModel: String = "openai/gpt-4o-mini"

    @AppStorage("PromptZen.cloudflareAccountId") private var cloudflareAccountId: String = ""
    @AppStorage("PromptZen.cloudflareAPIToken") private var cloudflareAPIToken: String = ""
    @AppStorage("PromptZen.cloudflareModel") private var cloudflareModel: String = "@cf/meta/llama-3.1-8b-instruct"

    @AppStorage("PromptZen.nvidiaNIMBaseURL") private var nvidiaNIMBaseURL: String = "https://integrate.api.nvidia.com/v1"
    @AppStorage("PromptZen.nvidiaNIMAPIKey") private var nvidiaNIMAPIKey: String = ""
    @AppStorage("PromptZen.nvidiaNIMModel") private var nvidiaNIMModel: String = "meta/llama-3.1-8b-instruct"

    @StateObject private var chatSession = PlaygroundChatSession()
    @StateObject private var tunnelConnect = PlaygroundTunnelConnectViewModel()
    @State private var playgroundText: String = ""

    @AppStorage("PromptZen.tunnelLocalPort") private var tunnelLocalPort: String = "8787"
    @AppStorage("PromptZen.ngrokExecutablePath") private var ngrokExecutablePath: String = ""

    private var selectedProviderBinding: Binding<PlaygroundAIProviderKind> {
        Binding(
            get: { PlaygroundAIProviderKind(rawValue: playgroundProviderRaw) ?? .ollama },
            set: { playgroundProviderRaw = $0.rawValue }
        )
    }

    private var selectedProvider: PlaygroundAIProviderKind {
        PlaygroundAIProviderKind(rawValue: playgroundProviderRaw) ?? .ollama
    }

    private var inputTokens: Int {
        TokenEstimator.estimateTokens(for: playgroundText)
    }

    private var env: [String: String] { ProcessInfo.processInfo.environment }

    private var effectiveOllamaAPIKey: String {
        let s = ollamaAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { return s }
        return env["OLLAMA_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var effectiveOpenRouterAPIKey: String {
        let s = openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { return s }
        return env["OPENROUTER_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var effectiveGeminiAPIKey: String {
        let s = geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { return s }
        return env["GEMINI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? env["GOOGLE_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var effectiveGroqAPIKey: String {
        keyOrEnv(stored: groqAPIKey, envKeys: ["GROQ_API_KEY"])
    }

    private var effectiveMistralAPIKey: String {
        keyOrEnv(stored: mistralAPIKey, envKeys: ["MISTRAL_API_KEY"])
    }

    private var effectiveHuggingFaceAPIKey: String {
        keyOrEnv(stored: huggingFaceAPIKey, envKeys: ["HF_TOKEN", "HUGGING_FACE_HUB_TOKEN"])
    }

    private var effectiveVercelAIGatewayAPIKey: String {
        keyOrEnv(stored: vercelAIGatewayAPIKey, envKeys: ["VERCEL_AI_GATEWAY_KEY", "AI_GATEWAY_API_KEY"])
    }

    private var effectiveOpenCodeZenAPIKey: String {
        keyOrEnv(stored: openCodeZenAPIKey, envKeys: ["OPENCODE_API_KEY"])
    }

    private var effectiveCerebrasAPIKey: String {
        keyOrEnv(stored: cerebrasAPIKey, envKeys: ["CEREBRAS_API_KEY"])
    }

    private var effectiveCohereAPIKey: String {
        keyOrEnv(stored: cohereAPIKey, envKeys: ["COHERE_API_KEY"])
    }

    private var effectiveGithubModelsToken: String {
        let s = githubModelsToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { return s }
        return env["GITHUB_MODELS_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? env["GITHUB_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var effectiveCloudflareAccountId: String {
        let s = cloudflareAccountId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { return s }
        return env["CLOUDFLARE_ACCOUNT_ID"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var effectiveCloudflareAPIToken: String {
        keyOrEnv(stored: cloudflareAPIToken, envKeys: ["CLOUDFLARE_API_TOKEN"])
    }

    private var effectiveNvidiaNIMAPIKey: String {
        keyOrEnv(stored: nvidiaNIMAPIKey, envKeys: ["NVIDIA_API_KEY"])
    }

    private func keyOrEnv(stored: String, envKeys: [String]) -> String {
        let s = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { return s }
        for k in envKeys {
            if let v = env[k]?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty { return v }
        }
        return ""
    }

    private func buildConfiguration() -> PlaygroundChatConfiguration {
        PlaygroundChatConfiguration(
            provider: selectedProvider,
            ollamaBaseURL: ollamaBaseURL,
            ollamaModel: ollamaModel,
            ollamaAPIKey: effectiveOllamaAPIKey,
            openRouterBaseURL: openRouterBaseURL,
            openRouterModel: openRouterModel,
            openRouterAPIKey: effectiveOpenRouterAPIKey,
            openRouterReferer: openRouterReferer,
            openRouterTitle: openRouterTitle,
            geminiAPIKey: effectiveGeminiAPIKey,
            geminiModel: geminiModel,
            groqAPIKey: effectiveGroqAPIKey,
            groqModel: groqModel,
            mistralAPIKey: effectiveMistralAPIKey,
            mistralModel: mistralModel,
            huggingFaceAPIKey: effectiveHuggingFaceAPIKey,
            huggingFaceBaseURL: huggingFaceBaseURL,
            huggingFaceModel: huggingFaceModel,
            vercelAIGatewayAPIKey: effectiveVercelAIGatewayAPIKey,
            vercelAIGatewayModel: vercelAIGatewayModel,
            openCodeZenAPIKey: effectiveOpenCodeZenAPIKey,
            openCodeZenModel: openCodeZenModel,
            cerebrasAPIKey: effectiveCerebrasAPIKey,
            cerebrasModel: cerebrasModel,
            cohereAPIKey: effectiveCohereAPIKey,
            cohereModel: cohereModel,
            githubModelsToken: effectiveGithubModelsToken,
            githubModelsModel: githubModelsModel,
            cloudflareAccountId: effectiveCloudflareAccountId,
            cloudflareAPIToken: effectiveCloudflareAPIToken,
            cloudflareModel: cloudflareModel,
            nvidiaNIMBaseURL: nvidiaNIMBaseURL,
            nvidiaNIMAPIKey: effectiveNvidiaNIMAPIKey,
            nvidiaNIMModel: nvidiaNIMModel
        )
    }

    private var canRunChat: Bool {
        let hasPrompt = !playgroundText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasPrompt else { return false }
        func nonEmpty(_ s: String) -> Bool { !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        switch selectedProvider {
        case .ollama:
            return true
        case .openRouter:
            return !effectiveOpenRouterAPIKey.isEmpty && nonEmpty(openRouterModel)
        case .googleGemini:
            return !effectiveGeminiAPIKey.isEmpty && nonEmpty(geminiModel)
        case .groq:
            return !effectiveGroqAPIKey.isEmpty && nonEmpty(groqModel)
        case .mistral:
            return !effectiveMistralAPIKey.isEmpty && nonEmpty(mistralModel)
        case .huggingFace:
            return !effectiveHuggingFaceAPIKey.isEmpty && nonEmpty(huggingFaceModel) && nonEmpty(huggingFaceBaseURL)
        case .vercelAIGateway:
            return !effectiveVercelAIGatewayAPIKey.isEmpty && nonEmpty(vercelAIGatewayModel)
        case .openCodeZen:
            return !effectiveOpenCodeZenAPIKey.isEmpty && nonEmpty(openCodeZenModel)
        case .cerebras:
            return !effectiveCerebrasAPIKey.isEmpty && nonEmpty(cerebrasModel)
        case .cohere:
            return !effectiveCohereAPIKey.isEmpty && nonEmpty(cohereModel)
        case .githubModels:
            return !effectiveGithubModelsToken.isEmpty && nonEmpty(githubModelsModel)
        case .cloudflareWorkersAI:
            return !effectiveCloudflareAccountId.isEmpty && !effectiveCloudflareAPIToken.isEmpty && nonEmpty(cloudflareModel)
        case .nvidiaNIM:
            return nonEmpty(nvidiaNIMBaseURL) && !effectiveNvidiaNIMAPIKey.isEmpty && nonEmpty(nvidiaNIMModel)
        }
    }

    private var missingCredentialsHint: String? {
        guard canRunChat == false,
              !playgroundText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        switch selectedProvider {
        case .ollama: return nil
        case .openRouter: return "Add OpenRouter API key and model."
        case .googleGemini: return "Add Gemini API key (Google AI Studio) and model id."
        case .groq: return "Add Groq API key and model."
        case .mistral: return "Add Mistral API key and model (La Plateforme / Codestral use same API)."
        case .huggingFace: return "Add HF token, base URL, and model id."
        case .vercelAIGateway: return "Add Vercel AI Gateway key and model."
        case .openCodeZen: return "Add OpenCode Zen API key; use a model routed to /chat/completions (see opencode.ai/docs/zen)."
        case .cerebras: return "Add Cerebras API key and model."
        case .cohere: return "Add Cohere API key and model."
        case .githubModels: return "Add GitHub PAT with models scope and model id."
        case .cloudflareWorkersAI: return "Add Cloudflare account id, API token (Workers AI), and model id."
        case .nvidiaNIM: return "Add NIM base URL from NVIDIA, API key, and model name."
        }
    }

    var body: some View {
        HSplitView {
            providersRail
                .frame(minWidth: 160, idealWidth: 188, maxWidth: 220)

            providerSettingsSidebar
                .frame(minWidth: 268, idealWidth: 300, maxWidth: 360)

            editorPane
                .frame(minWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var providersRail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Providers")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
            Text("Green: at least one successful run. Red: last run failed.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            List(selection: selectedProviderBinding) {
                ForEach(PlaygroundAIProviderKind.allCases) { kind in
                    HStack(spacing: 8) {
                        providerRunStatusDot(chatSession.statusDot(for: kind))
                        Label(kind.displayName, systemImage: kind.symbolName)
                    }
                    .tag(kind)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Spacer(minLength: 0)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    @ViewBuilder
    private func providerRunStatusDot(_ status: PlaygroundProviderStatusDot) -> some View {
        switch status {
        case .none:
            Circle()
                .fill(Color.clear)
                .frame(width: 9, height: 9)
                .accessibilityHidden(true)
        case .verified:
            Circle()
                .fill(Color(nsColor: .systemGreen))
                .frame(width: 9, height: 9)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                .accessibilityLabel("At least one successful run")
        case .lastFailed:
            Circle()
                .fill(Color(nsColor: .systemRed))
                .frame(width: 9, height: 9)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                .accessibilityLabel("Last run failed")
        }
    }

    private var providerSettingsSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Playground")
                    .font(.title2.bold())

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Curated from").font(.caption).foregroundStyle(.secondary)
                    Link(
                        "free-llm-api-resources",
                        destination: URL(string: "https://github.com/cheahjs/free-llm-api-resources")!
                    )
                    .font(.caption)
                    Text("— respect limits and terms.").font(.caption).foregroundStyle(.secondary)
                }

                switch selectedProvider {
                case .ollama: ollamaSettings
                case .openRouter: openRouterSettings
                case .googleGemini: geminiSettings
                case .groq: groqSettings
                case .mistral: mistralSettings
                case .huggingFace: huggingFaceSettings
                case .vercelAIGateway: vercelSettings
                case .openCodeZen: zenSettings
                case .cerebras: cerebrasSettings
                case .cohere: cohereSettings
                case .githubModels: githubSettings
                case .cloudflareWorkersAI: cloudflareSettings
                case .nvidiaNIM: nvidiaSettings
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ollamaSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Ollama Cloud")
            Text("30s per catalog model, then 60s. Key optional for local.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            TextField("API base URL", text: $ollamaBaseURL).textFieldStyle(.roundedBorder)
            TextField("Preferred model (first)", text: $ollamaModel).textFieldStyle(.roundedBorder)
            Button("Reset Ollama defaults") {
                ollamaBaseURL = "https://ollama.com"
                ollamaModel = "deepseek-v3.1:latest"
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            SecureField("Ollama API key", text: $ollamaAPIKey).textFieldStyle(.roundedBorder)
            Text("Env: OLLAMA_API_KEY").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var openRouterSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("OpenRouter")
            Link("OpenRouter quickstart", destination: URL(string: "https://openrouter.ai/docs/quickstart")!)
                .font(.caption)
            TextField("API base URL", text: $openRouterBaseURL).textFieldStyle(.roundedBorder)
            TextField("Model id", text: $openRouterModel).textFieldStyle(.roundedBorder)
            SecureField("API key", text: $openRouterAPIKey).textFieldStyle(.roundedBorder)
            TextField("HTTP-Referer (optional)", text: $openRouterReferer).textFieldStyle(.roundedBorder)
            TextField("X-OpenRouter-Title (optional)", text: $openRouterTitle).textFieldStyle(.roundedBorder)
            Text("Env: OPENROUTER_API_KEY").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var geminiSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Google Gemini (AI Studio)")
            HStack(spacing: 8) {
                Link("Get API key", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                Link("Gemini docs", destination: URL(string: "https://ai.google.dev/gemini-api/docs/quickstart")!)
            }
            .font(.caption)
            SecureField("API key", text: $geminiAPIKey).textFieldStyle(.roundedBorder)
            TextField("Model id (no models/ prefix)", text: $geminiModel).textFieldStyle(.roundedBorder)
            Text("Header x-goog-api-key. Env: GEMINI_API_KEY or GOOGLE_API_KEY.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var groqSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Groq")
            Link("Groq console", destination: URL(string: "https://console.groq.com/")!)
                .font(.caption)
            SecureField("API key", text: $groqAPIKey).textFieldStyle(.roundedBorder)
            TextField("Model id", text: $groqModel).textFieldStyle(.roundedBorder)
            Text("Env: GROQ_API_KEY").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var mistralSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Mistral (La Plateforme / Codestral)")
            Link("Mistral console", destination: URL(string: "https://console.mistral.ai/")!)
                .font(.caption)
            SecureField("API key", text: $mistralAPIKey).textFieldStyle(.roundedBorder)
            TextField("Model id", text: $mistralModel).textFieldStyle(.roundedBorder)
            Text("Env: MISTRAL_API_KEY").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var huggingFaceSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Hugging Face Inference")
            Link("HF chat completions guide", destination: URL(string: "https://huggingface.co/docs/inference-providers/en/guides/chat-completion")!)
                .font(.caption)
            SecureField("HF token", text: $huggingFaceAPIKey).textFieldStyle(.roundedBorder)
            TextField("OpenAI-compatible base URL", text: $huggingFaceBaseURL).textFieldStyle(.roundedBorder)
            TextField("Model id", text: $huggingFaceModel).textFieldStyle(.roundedBorder)
            Text("Env: HF_TOKEN").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var vercelSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Vercel AI Gateway")
            Link("Vercel AI Gateway docs", destination: URL(string: "https://vercel.com/docs/ai-gateway")!)
                .font(.caption)
            SecureField("API key", text: $vercelAIGatewayAPIKey).textFieldStyle(.roundedBorder)
            TextField("Model id", text: $vercelAIGatewayModel).textFieldStyle(.roundedBorder)
            Text("Env: VERCEL_AI_GATEWAY_KEY or AI_GATEWAY_API_KEY").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var zenSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("OpenCode Zen")
            Link("OpenCode Zen docs", destination: URL(string: "https://opencode.ai/docs/zen/")!)
                .font(.caption)
            SecureField("API key", text: $openCodeZenAPIKey).textFieldStyle(.roundedBorder)
            TextField("Model id (chat/completions route)", text: $openCodeZenModel).textFieldStyle(.roundedBorder)
            Text("Env: OPENCODE_API_KEY").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var cerebrasSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Cerebras")
            Link("Cerebras inference docs", destination: URL(string: "https://inference-docs.cerebras.ai/")!)
                .font(.caption)
            SecureField("API key", text: $cerebrasAPIKey).textFieldStyle(.roundedBorder)
            TextField("Model id", text: $cerebrasModel).textFieldStyle(.roundedBorder)
            Text("Env: CEREBRAS_API_KEY").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var cohereSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Cohere")
            Link("Cohere Chat v2", destination: URL(string: "https://docs.cohere.com/v2/docs/chat-api")!)
                .font(.caption)
            SecureField("API key", text: $cohereAPIKey).textFieldStyle(.roundedBorder)
            TextField("Model id", text: $cohereModel).textFieldStyle(.roundedBorder)
            Text("Env: COHERE_API_KEY").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var githubSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("GitHub Models")
            Link("GitHub Models quickstart", destination: URL(string: "https://docs.github.com/en/github-models/quickstart")!)
                .font(.caption)
            SecureField("GitHub token", text: $githubModelsToken).textFieldStyle(.roundedBorder)
            TextField("Model id", text: $githubModelsModel).textFieldStyle(.roundedBorder)
            Text("Env: GITHUB_MODELS_TOKEN or GITHUB_TOKEN").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var cloudflareSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Cloudflare Workers AI")
            Link("Cloudflare Workers AI (OpenAI compat)", destination: URL(string: "https://developers.cloudflare.com/workers-ai/configuration/open-ai-compatibility/")!)
                .font(.caption)
            TextField("Account ID", text: $cloudflareAccountId).textFieldStyle(.roundedBorder)
            SecureField("API token", text: $cloudflareAPIToken).textFieldStyle(.roundedBorder)
            TextField("Model id (@cf/…)", text: $cloudflareModel).textFieldStyle(.roundedBorder)
            Text("Env: CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_API_TOKEN").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var nvidiaSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("NVIDIA NIM")
            Link("NVIDIA NIM docs", destination: URL(string: "https://docs.nvidia.com/nim/")!)
                .font(.caption)
            TextField("Base URL (…/v1)", text: $nvidiaNIMBaseURL).textFieldStyle(.roundedBorder)
            SecureField("API key", text: $nvidiaNIMAPIKey).textFieldStyle(.roundedBorder)
            TextField("Model name", text: $nvidiaNIMModel).textFieldStyle(.roundedBorder)
            Text("Env: NVIDIA_API_KEY").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s).font(.headline)
    }

    private var webTunnelSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Serves a chat page on this Mac (loopback) and on your LAN when connected. Use the LAN URL on an iPhone on the same Wi‑Fi. ngrok adds a public URL when it works. Requests use the Playground provider and keys from this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    TextField("Local port", text: $tunnelLocalPort)
                        .frame(width: 92)
                        .textFieldStyle(.roundedBorder)
                        .disabled(tunnelConnect.isConnected)
                    TextField("ngrok executable path (optional)", text: $ngrokExecutablePath)
                        .textFieldStyle(.roundedBorder)
                        .disabled(tunnelConnect.isConnected)
                }
                HStack(spacing: 12) {
                    if !tunnelConnect.isConnected {
                        Button {
                            Task {
                                await tunnelConnect.connect(
                                    portString: tunnelLocalPort,
                                    ngrokExecutablePath: ngrokExecutablePath
                                )
                            }
                        } label: {
                            Label("Connect", systemImage: "link.badge.plus")
                        }
                        .disabled(tunnelConnect.isBusy || chatSession.isRunning)
                    }
                    if tunnelConnect.isConnected {
                        Button {
                            Task { await tunnelConnect.disconnect() }
                        } label: {
                            Label("Disconnect", systemImage: "link.badge.minus")
                        }
                    }
                }
                tunnelStatusBlock
            }
        } label: {
            Label("Web tunnel", systemImage: "cable.connector")
        }
    }

    @ViewBuilder
    private var tunnelStatusBlock: some View {
        switch tunnelConnect.phase {
        case .disconnected:
            EmptyView()
        case .busy(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed(let err):
            Text(err)
                .font(.caption)
                .foregroundStyle(.red)
        case .connected(let local, let lanURL, let publicURL, let tunnelWarning):
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Mac only").font(.caption).foregroundStyle(.secondary)
                        Text(local).font(.caption).textSelection(.enabled)
                    }
                    Button("Copy") { copyToPasteboard(local) }
                        .controlSize(.small)
                }
                if let lan = lanURL, !lan.isEmpty {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Same Wi‑Fi (iPhone, iPad, etc.)").font(.caption).foregroundStyle(.secondary)
                            Text(lan).font(.caption).textSelection(.enabled)
                        }
                        Button("Copy") { copyToPasteboard(lan) }
                            .controlSize(.small)
                    }
                }
                if let pub = publicURL, !pub.isEmpty {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Public URL (ngrok)").font(.caption).foregroundStyle(.secondary)
                            Text(pub).font(.caption).textSelection(.enabled)
                        }
                        Button("Copy") { copyToPasteboard(pub) }
                            .controlSize(.small)
                    }
                }
                if let warn = tunnelWarning, !warn.isEmpty {
                    Text(warn)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if !tunnelConnect.tunnelSecret.isEmpty {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tunnel secret (Authorization: Bearer …)").font(.caption).foregroundStyle(.secondary)
                            Text(tunnelConnect.tunnelSecret)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        Button("Copy") { copyToPasteboard(tunnelConnect.tunnelSecret) }
                            .controlSize(.small)
                    }
                }
                Text("Open a URL in a browser on that device. If the phone cannot connect, confirm same Wi‑Fi and allow PromptZen in macOS Firewall. POST /chat requires the secret. Disconnect stops the server and ngrok.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    private var editorPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Paste a prompt to measure or send")
                        .font(.headline)
                    Spacer()
                    Text("Input ~\(inputTokens) tok")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                webTunnelSection
                    .padding(.horizontal, 16)

                TextEditor(text: $playgroundText)
                    .font(.body)
                    .frame(minHeight: 160)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    Button {
                        chatSession.run(prompt: playgroundText, configuration: buildConfiguration())
                    } label: {
                        Label("Run chat", systemImage: "paperplane.fill")
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(chatSession.isRunning || !canRunChat)

                    Button("Cancel") {
                        chatSession.cancel()
                    }
                    .disabled(!chatSession.isRunning)

                    if chatSession.isRunning {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)

                if let hint = missingCredentialsHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16)
                }

                if !chatSession.statusLine.isEmpty {
                    Text(chatSession.statusLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }

                if let used = chatSession.usedProviderSummary {
                    Text(used)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                }

                Text("Token count is heuristic (~4 bytes/token). Sends text to the selected provider only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)

                Divider()
                    .padding(.vertical, 4)

                Text("Response")
                    .font(.headline)
                    .padding(.horizontal, 16)

                Group {
                    if chatSession.responseText.isEmpty {
                        Text("Run chat to see the model reply here.")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(chatSession.responseText)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor).opacity(0.6)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
