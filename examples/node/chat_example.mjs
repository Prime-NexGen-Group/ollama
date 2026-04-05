// Ollama Node.js Examples
// Usage: npm install ollama && node chat_example.mjs

const OLLAMA_URL = process.env.OLLAMA_URL || "http://localhost:11434";

async function chat(model, message) {
  const resp = await fetch(`${OLLAMA_URL}/api/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model,
      messages: [{ role: "user", content: message }],
      stream: false,
    }),
  });
  const data = await resp.json();
  return data.message.content;
}

async function listModels() {
  const resp = await fetch(`${OLLAMA_URL}/api/tags`);
  const data = await resp.json();
  return data.models;
}

async function getEmbedding(model, text) {
  const resp = await fetch(`${OLLAMA_URL}/api/embed`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ model, input: text }),
  });
  const data = await resp.json();
  return data.embeddings[0];
}

// --- Run examples ---
console.log("=== Available Models ===");
const models = await listModels();
for (const m of models) {
  console.log(`  ${m.name.padEnd(30)} ${(m.size / 1e9).toFixed(1)} GB`);
}

console.log("\n=== Chat ===");
const answer = await chat("llama3.2", "What is Docker in one sentence?");
console.log(`  ${answer}`);

console.log("\n=== Embeddings ===");
const vec = await getEmbedding("nomic-embed-text", "Hello world");
console.log(`  Dimensions: ${vec.length}`);
console.log(`  First 5: [${vec.slice(0, 5).map((v) => v.toFixed(4)).join(", ")}]`);
