import Foundation

/// Playground backends aligned with [free-llm-api-resources](https://github.com/cheahjs/free-llm-api-resources) “Free providers” (plus Ollama).
enum PlaygroundAIProviderKind: String, CaseIterable, Identifiable, Hashable, Sendable {
    case ollama
    case openRouter
    case googleGemini
    case groq
    case mistral
    case huggingFace
    case vercelAIGateway
    case openCodeZen
    case cerebras
    case cohere
    case githubModels
    case cloudflareWorkersAI
    case nvidiaNIM

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ollama: return "Ollama"
        case .openRouter: return "OpenRouter"
        case .googleGemini: return "Gemini"
        case .groq: return "Groq"
        case .mistral: return "Mistral"
        case .huggingFace: return "Hugging Face"
        case .vercelAIGateway: return "Vercel AI"
        case .openCodeZen: return "OpenCode Zen"
        case .cerebras: return "Cerebras"
        case .cohere: return "Cohere"
        case .githubModels: return "GitHub Models"
        case .cloudflareWorkersAI: return "Cloudflare"
        case .nvidiaNIM: return "NVIDIA NIM"
        }
    }

    var symbolName: String {
        switch self {
        case .ollama: return "cloud.fill"
        case .openRouter: return "network"
        case .googleGemini: return "sparkles"
        case .groq: return "bolt.fill"
        case .mistral: return "wind"
        case .huggingFace: return "face.smiling"
        case .vercelAIGateway: return "triangle.fill"
        case .openCodeZen: return "cpu"
        case .cerebras: return "square.stack.3d.up"
        case .cohere: return "bubble.left.and.bubble.right"
        case .githubModels: return "cat.fill"
        case .cloudflareWorkersAI: return "cloud.sun.fill"
        case .nvidiaNIM: return "cpu.fill"
        }
    }
}
