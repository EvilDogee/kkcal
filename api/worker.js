/**
 * NutriLens AI endpoint for Cloudflare Workers.
 * Configure OPENAI_API_KEY as a Worker secret. Never expose it in the frontend.
 * Deploy this file as a Worker, then paste its URL into NutriLens Settings.
 */
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Content-Type": "application/json; charset=utf-8"
};
const reply = (body, status = 200) => new Response(JSON.stringify(body), { status, headers: cors });
export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    if (request.method !== "POST") return reply({ error: "Use POST" }, 405);
    if (!env.OPENAI_API_KEY) return reply({ error: "Server secret OPENAI_API_KEY is not configured" }, 500);
    let body;
    try { body = await request.json(); } catch { return reply({ error: "Invalid JSON" }, 400); }
    const description = typeof body.description === "string" ? body.description.slice(0, 1500) : "";
    const image = typeof body.image === "string" ? body.image : "";
    if (image && (!/^data:image\/(jpeg|jpg|png|webp|gif);base64,/i.test(image) || image.length > 12_000_000)) {
      return reply({ error: "Image must be a supported data URL under 9 MB encoded" }, 400);
    }
    if (!image && !description) return reply({ error: "Provide an image or description" }, 400);
    const content = [{ type: "input_text", text:
      "Estimate nutrition for one visible serving of food. Use the image and user's description. " +
      "Return only a JSON object with keys name (Russian dish name), kcal (integer kcal), p (protein grams), " +
      "f (fat grams), c (carbohydrate grams), weight (estimated serving grams), emoji (one suitable emoji), " +
      "confidence (low, medium, or high), notes (short Russian uncertainty note). " +
      "Do not claim exactness; account for uncertainty and do not invent precise ingredients when unclear. " +
      "User description: " + (description || "No description provided.")
    }];
    if (image) content.push({ type: "input_image", image_url: image, detail: "high" });
    let upstream;
    try {
      upstream = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: { "Authorization": "Bearer " + env.OPENAI_API_KEY, "Content-Type": "application/json" },
        body: JSON.stringify({
          model: env.OPENAI_MODEL || "gpt-4.1-mini",
          input: [{ role: "user", content }],
          max_output_tokens: 450
        })
      });
    } catch {
      return reply({ error: "Could not reach AI provider" }, 502);
    }
    const raw = await upstream.json().catch(() => ({}));
    if (!upstream.ok) return reply({ error: "AI provider request failed", status: upstream.status, details: raw.error?.message || "No details" }, 502);
    const text = (raw.output || []).flatMap(item => item.content || []).filter(item => item.type === "output_text").map(item => item.text).join("\n");
    let parsed;
    try {
      const cleaned = text.replace(/^\s*```(?:json)?/i, "").replace(/```\s*$/, "").trim();
      parsed = JSON.parse(cleaned);
    } catch {
      return reply({ error: "AI returned an unreadable result" }, 502);
    }
    const numeric = ["kcal", "p", "f", "c", "weight"];
    for (const key of numeric) {
      parsed[key] = Number(parsed[key]);
      if (!Number.isFinite(parsed[key]) || parsed[key] < 0) return reply({ error: "AI returned invalid nutrition values" }, 502);
    }
    parsed.name = String(parsed.name || "Блюдо").slice(0, 120);
    parsed.notes = String(parsed.notes || "Оценка приблизительна; проверь размер порции.").slice(0, 500);
    return reply({ food: parsed });
  }
};