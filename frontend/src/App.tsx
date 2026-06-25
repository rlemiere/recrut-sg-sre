import { useState } from "react";

const API_URL = import.meta.env.VITE_API_URL ?? "";

function validateUrl(input: string): string | null {
  if (!input.trim()) return "Please enter a URL.";
  try {
    const { protocol } = new URL(input);
    if (protocol !== "http:" && protocol !== "https:")
      return "URL must use http or https.";
  } catch {
    return "Invalid URL format.";
  }
  return null;
}

export default function App() {
  const [url, setUrl] = useState("");
  const [shortUrl, setShortUrl] = useState<string | null>(null);
  const [serverError, setServerError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [copied, setCopied] = useState(false);

  const urlError = url.trim() ? validateUrl(url) : null;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setServerError(null);
    setShortUrl(null);

    if (validateUrl(url)) return;

    setLoading(true);
    try {
      const res = await fetch(`${API_URL}/links`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ url }),
      });
      const data = await res.json();
      if (res.status === 201) {
        const base = API_URL || window.location.origin;
        setShortUrl(`${base}/l/${data.id}`);
      } else {
        setServerError(data.detail ?? "An error occurred.");
      }
    } catch {
      setServerError("Network error — could not reach the server.");
    } finally {
      setLoading(false);
    }
  }

  async function handleCopy() {
    if (!shortUrl) return;
    await navigator.clipboard.writeText(shortUrl);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  return (
    <div style={styles.page}>
      <div style={styles.card}>
        <h1 style={styles.title}>URL Shortener</h1>
        <form onSubmit={handleSubmit} style={styles.form}>
          <input
            type="text"
            value={url}
            onChange={(e) => {
              setUrl(e.target.value);
              setServerError(null);
            }}
            placeholder="https://example.com"
            style={{
              ...styles.input,
              borderColor: urlError ? "#dc2626" : "#ccc",
            }}
            disabled={loading}
          />
          <button
            type="submit"
            style={styles.button}
            disabled={loading || urlError !== null}
          >
            {loading ? "Shortening…" : "Shorten"}
          </button>
        </form>

        {urlError && <p style={styles.error}>{urlError}</p>}
        {serverError && <p style={styles.error}>{serverError}</p>}

        {shortUrl && (
          <div style={styles.result}>
            <a
              href={shortUrl}
              target="_blank"
              rel="noopener noreferrer"
              style={styles.link}
            >
              {shortUrl}
            </a>
            <button onClick={handleCopy} style={styles.copyButton}>
              {copied ? "Copied!" : "Copy"}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  page: {
    minHeight: "100vh",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    fontFamily: "system-ui, sans-serif",
    background: "#f5f5f5",
  },
  card: {
    background: "#fff",
    borderRadius: 12,
    padding: "2rem",
    width: "100%",
    maxWidth: 480,
    boxShadow: "0 2px 12px rgba(0,0,0,0.1)",
  },
  title: {
    margin: "0 0 1.5rem",
    fontSize: "1.5rem",
    fontWeight: 700,
  },
  form: {
    display: "flex",
    gap: 8,
  },
  input: {
    flex: 1,
    padding: "0.6rem 0.8rem",
    fontSize: "1rem",
    border: "1px solid #ccc",
    borderRadius: 6,
    outline: "none",
  },
  button: {
    padding: "0.6rem 1.2rem",
    fontSize: "1rem",
    background: "#2563eb",
    color: "#fff",
    border: "none",
    borderRadius: 6,
    cursor: "pointer",
  },
  error: {
    marginTop: "1rem",
    color: "#dc2626",
    fontSize: "0.9rem",
  },
  result: {
    marginTop: "1rem",
    display: "flex",
    alignItems: "center",
    gap: 8,
    background: "#f0f7ff",
    borderRadius: 6,
    padding: "0.6rem 0.8rem",
  },
  link: {
    flex: 1,
    color: "#2563eb",
    wordBreak: "break-all",
    fontSize: "0.95rem",
  },
  copyButton: {
    padding: "0.4rem 0.8rem",
    fontSize: "0.85rem",
    background: "#e5e7eb",
    border: "none",
    borderRadius: 4,
    cursor: "pointer",
    whiteSpace: "nowrap",
  },
};
