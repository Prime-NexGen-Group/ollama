"""
Ollama Python Examples
Usage: pip install requests && python chat_example.py
"""
import requests

OLLAMA_URL = "http://localhost:11434"  # Change for remote server


def chat(model: str, message: str, system: str = None) -> str:
    """Send a chat message and get a response."""
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": message})

    resp = requests.post(f"{OLLAMA_URL}/api/chat", json={
        "model": model,
        "messages": messages,
        "stream": False,
    })
    resp.raise_for_status()
    return resp.json()["message"]["content"]


def generate(model: str, prompt: str) -> str:
    """Simple text generation."""
    resp = requests.post(f"{OLLAMA_URL}/api/generate", json={
        "model": model,
        "prompt": prompt,
        "stream": False,
    })
    resp.raise_for_status()
    return resp.json()["response"]


def list_models() -> list:
    """List all available models."""
    resp = requests.get(f"{OLLAMA_URL}/api/tags")
    resp.raise_for_status()
    return resp.json()["models"]


def get_embedding(model: str, text: str) -> list:
    """Get embedding vector for text."""
    resp = requests.post(f"{OLLAMA_URL}/api/embed", json={
        "model": model,
        "input": text,
    })
    resp.raise_for_status()
    return resp.json()["embeddings"][0]


if __name__ == "__main__":
    # List models
    print("=== Available Models ===")
    for m in list_models():
        size_gb = m["size"] / 1e9
        print(f"  {m['name']:30s} {size_gb:.1f} GB")

    # Chat
    print("\n=== Chat ===")
    response = chat("llama3.2", "What is Docker in one sentence?")
    print(f"  {response}")

    # Chat with system prompt
    print("\n=== Chat with System Prompt ===")
    response = chat(
        "llama3.2",
        "Write a hello world in Python",
        system="You are a coding assistant. Only output code, no explanation.",
    )
    print(f"  {response}")

    # Generate
    print("\n=== Generate ===")
    response = generate("llama3.2", "List 3 benefits of containers:")
    print(f"  {response}")

    # Embeddings
    print("\n=== Embeddings ===")
    vec = get_embedding("nomic-embed-text", "Hello world")
    print(f"  Dimensions: {len(vec)}")
    print(f"  First 5 values: {vec[:5]}")
