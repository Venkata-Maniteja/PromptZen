import Foundation

/// Single-page chat UI served at `GET /`. Placeholder `__PROMPTZEN_SECRET__` is replaced with the tunnel token.
enum PlaygroundTunnelWebHTML {
    static func page(injectedSecret: String) -> String {
        let escaped = injectedSecret
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return template.replacingOccurrences(of: "__PROMPTZEN_SECRET__", with: escaped)
    }

    private static let template = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>PromptZen Playground</title>
      <style>
        :root { font-family: system-ui, sans-serif; background: #1a1a1e; color: #eee; }
        body { max-width: 720px; margin: 24px auto; padding: 0 16px; }
        h1 { font-size: 1.25rem; }
        #log { border: 1px solid #444; border-radius: 8px; min-height: 240px; padding: 12px; overflow-y: auto; background: #111; margin-bottom: 12px; }
        .msg { margin: 8px 0; white-space: pre-wrap; }
        .user { color: #8cb4ff; }
        .api { color: #9dffa3; }
        .err { color: #ff8a8a; }
        #row { display: flex; gap: 8px; }
        #input { flex: 1; padding: 10px; border-radius: 6px; border: 1px solid #555; background: #222; color: #eee; }
        button { padding: 10px 16px; border-radius: 6px; border: none; background: #3d6ad6; color: #fff; cursor: pointer; }
        button:disabled { opacity: 0.5; cursor: not-allowed; }
      </style>
    </head>
    <body>
      <h1>PromptZen tunnel chat</h1>
      <p style="opacity:0.7;font-size:0.85rem;">Sends <code>POST /chat</code> to this host using your Playground provider from the Mac app.</p>
      <div id="log"></div>
      <div id="row">
        <input id="input" type="text" placeholder="Message…" autocomplete="off" />
        <button id="send" type="button">Send</button>
      </div>
      <script>
        const SECRET = "__PROMPTZEN_SECRET__";
        const log = document.getElementById("log");
        const input = document.getElementById("input");
        const btn = document.getElementById("send");

        function add(cls, label, text) {
          const p = document.createElement("div");
          p.className = "msg " + cls;
          p.textContent = label + text;
          log.appendChild(p);
          log.scrollTop = log.scrollHeight;
        }

        function send() {
          const message = input.value.trim();
          if (!message) return;
          input.value = "";
          add("user", "You: ", message);
          btn.disabled = true;
          const body = JSON.stringify({ message });
          // Safari (especially on iOS) often uses chunked encoding for fetch() POST bodies.
          // FlyingFox only reads Content-Length bodies, so the server saw an empty body → 500.
          // XMLHttpRequest typically sends a fixed Content-Length, which the server can read.
          const xhr = new XMLHttpRequest();
          xhr.open("POST", "/chat", true);
          xhr.setRequestHeader("Content-Type", "application/json");
          xhr.setRequestHeader("Authorization", "Bearer " + SECRET);
          xhr.onload = function () {
            btn.disabled = false;
            let data = {};
            try {
              data = xhr.responseText ? JSON.parse(xhr.responseText) : {};
            } catch (e) {
              add("err", "Error: ", xhr.responseText || xhr.statusText || "bad response");
              return;
            }
            if (xhr.status < 200 || xhr.status >= 300) {
              add("err", "Error: ", data.error || xhr.statusText || "request failed");
            } else {
              add("api", "Assistant: ", data.reply || "(empty)");
            }
          };
          xhr.onerror = function () {
            btn.disabled = false;
            add("err", "Error: ", "Network error");
          };
          xhr.send(body);
        }

        btn.addEventListener("click", send);
        input.addEventListener("keydown", (e) => { if (e.key === "Enter") send(); });
      </script>
    </body>
    </html>
    """
}
