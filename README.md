# PromptZen

macOS app for writing and organizing prompts, with a built-in **Playground** for sending text to many LLM providers using your own API keys.

This document focuses on the Playground and its optional **web tunnel**.

---

## Playground overview

The Playground is a split view: a **provider list** on the left (with per-provider settings) and a **prompt editor** on the right. Choose a backend, paste a prompt, then **Run** to send it. **Cancel** stops an in-flight request.

### Supported providers

Settings and defaults live in app storage (`AppStorage` / `UserDefaults`). Several keys also fall back to **environment variables** when the in-app field is empty (see the inline hints in the UI).

| Provider | Notes |
|----------|--------|
| **Ollama** | Cloud rotation: multiple models are tried in order with phased timeouts (see below). |
| **OpenRouter** | OpenAI-compatible API; optional HTTP-Referer and X-OpenRouter-Title. |
| **Gemini** | Google AI API. |
| **Groq**, **Mistral**, **Hugging Face**, **Vercel AI Gateway**, **OpenCode Zen**, **Cerebras**, **Cohere**, **GitHub Models**, **Cloudflare Workers AI**, **NVIDIA NIM** | Each uses the provider’s documented chat/completions (or native) API shape implemented in the app. |

Provider choices are aligned with the spirit of [free-llm-api-resources](https://github.com/cheahjs/free-llm-api-resources); you are responsible for accounts, quotas, and acceptable use for each service.

### Routing and failover

- **Run** and the **web tunnel** both use `ChatProviderRouter.forPlayground` with the same configuration as the sidebar.
- For **Ollama**, the router builds a **rotation** over a catalog of cloud models (your chosen model is tried first), then runs **phased failover**: each model gets **30 seconds** in the first pass and **60 seconds** in the second pass. Timeouts and certain transport errors move to the next model.
- Other providers use a **single** client with the same two phase timeouts for retries where the router allows it.

### Sidebar status dots

Next to each provider name, a small indicator shows recent **Run** health for that provider (persisted on disk):

- **Green** — at least one successful completion.
- **Red** — the last run failed.
- **Clear** — no recorded outcome yet.

---

## Web tunnel

The **Web tunnel** section (in the Playground editor area) starts a small **HTTP server** on your Mac so you can chat from a browser while the Mac performs LLM calls with your Playground settings and keys.

### Connect and URLs

1. Choose a **local port** (default `8787`).
2. Click **Connect**. The app generates or reuses a **tunnel secret** (stored under `PromptZen.tunnelWebSecret`).
3. After connecting you will see:
   - **This Mac only** — `http://127.0.0.1:<port>/`
   - **Same Wi‑Fi** — `http://<Mac-LAN-IP>:<port>/` (for phones and tablets on the same network)
   - **Public URL** — when **ngrok** starts successfully, an `https://…` URL from your ngrok account

The server listens on **all interfaces** (`0.0.0.0`) so LAN clients can reach it. Ensure **macOS Firewall** allows incoming connections for PromptZen if prompted.

### ngrok

- Optional **ngrok executable path** if `ngrok` is not on the app’s `PATH` (common when launching from Finder). You can paste the output of `which ngrok` from Terminal.
- The app starts a **child** `ngrok http` process and reads the public URL from the agent’s local HTTP API. It uses a **dedicated loopback port (14043)** for that child’s API so it does not clash with another ngrok you may already have on port 4040.
- You need a valid **ngrok authtoken** (`ngrok config add-authtoken …`) for public URLs to work.

### HTTP API (for custom clients)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/` | Single-page chat UI (HTML). The tunnel secret is embedded for browser use. |
| `OPTIONS` | `/chat` | CORS preflight. |
| `POST` | `/chat` | JSON body: `{ "message": "<user text>" }`. Auth: `Authorization: Bearer <tunnel secret>` **or** same value in `"secret"` in the JSON body. |

Responses are JSON: `{ "reply": "…" }` on success or `{ "error": "…" }` on failure. The served HTML uses **XMLHttpRequest** for `POST /chat` so **Safari on iOS** sends a body the embedded server can read reliably.

### Disconnect

**Disconnect** stops the local HTTP server and the ngrok child process started by the app.

---

## Building (Swift Package)

From the repository root:

```bash
swift build
```

The Playground tunnel depends on [FlyingFox](https://github.com/swhitty/FlyingFox) for the embedded HTTP server.

---

## Privacy and security

- API keys and tunnel secrets stay on **your Mac** in app storage / UserDefaults.
- The tunnel secret protects `POST /chat`. Anyone who can reach the URL on your LAN could load `GET /` if you expose the server; treat the LAN URL like a **shared link** and use **Disconnect** when finished.
- Prefer **HTTPS** (ngrok) when exposing chat to the internet.
