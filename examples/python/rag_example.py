"""
RAG (Retrieval-Augmented Generation) Example
Embed documents, find relevant ones, then ask the model with context.

Usage: pip install requests && python rag_example.py
"""
import requests
import math

OLLAMA_URL = "http://localhost:11434"
EMBED_MODEL = "nomic-embed-text"
CHAT_MODEL = "llama3.2"


def embed(texts: list[str]) -> list[list[float]]:
    """Get embeddings for a list of texts."""
    resp = requests.post(f"{OLLAMA_URL}/api/embed", json={
        "model": EMBED_MODEL,
        "input": texts,
    })
    resp.raise_for_status()
    return resp.json()["embeddings"]


def cosine_similarity(a: list[float], b: list[float]) -> float:
    """Compute cosine similarity between two vectors."""
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(x * x for x in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)


def search(query: str, documents: list[str], doc_embeddings: list, top_k: int = 3):
    """Find the most relevant documents for a query."""
    query_embedding = embed([query])[0]
    scores = [
        (i, cosine_similarity(query_embedding, doc_emb))
        for i, doc_emb in enumerate(doc_embeddings)
    ]
    scores.sort(key=lambda x: x[1], reverse=True)
    return [(documents[i], score) for i, score in scores[:top_k]]


def ask_with_context(question: str, context_docs: list[str]) -> str:
    """Ask a question with retrieved context."""
    context = "\n\n".join(f"Document {i+1}: {doc}" for i, doc in enumerate(context_docs))
    resp = requests.post(f"{OLLAMA_URL}/api/chat", json={
        "model": CHAT_MODEL,
        "messages": [
            {
                "role": "system",
                "content": "Answer the user's question based ONLY on the provided context. "
                           "If the answer isn't in the context, say so.",
            },
            {
                "role": "user",
                "content": f"Context:\n{context}\n\nQuestion: {question}",
            },
        ],
        "stream": False,
    })
    resp.raise_for_status()
    return resp.json()["message"]["content"]


if __name__ == "__main__":
    # Sample knowledge base
    documents = [
        "Ollama runs large language models locally on your machine.",
        "Docker volumes allow data to persist across container restarts.",
        "NVIDIA Container Toolkit enables GPU access from Docker containers.",
        "Open WebUI provides a ChatGPT-like interface for Ollama.",
        "nomic-embed-text generates 768-dimensional text embeddings.",
        "DeepSeek R1 is a reasoning model that shows its thinking process.",
        "Models are stored in ~/.ollama/models by default.",
        "The Ollama API runs on port 11434 by default.",
    ]

    print("Embedding documents...")
    doc_embeddings = embed(documents)
    print(f"Embedded {len(documents)} documents\n")

    # Search and ask
    questions = [
        "How do I keep my models when restarting Docker?",
        "What port does Ollama use?",
        "Which model can show reasoning steps?",
    ]

    for question in questions:
        print(f"Q: {question}")
        results = search(question, documents, doc_embeddings, top_k=2)
        print(f"  Retrieved:")
        for doc, score in results:
            print(f"    [{score:.3f}] {doc}")

        context_docs = [doc for doc, _ in results]
        answer = ask_with_context(question, context_docs)
        print(f"  A: {answer}\n")
