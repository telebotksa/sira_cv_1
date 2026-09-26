// Cloudflare Worker: AI proxy for Free AI CV Maker.
//
// The model API key lives here (as a secret), never inside the app.
// Deploy:  see backend/README.md
// Secrets: ANTHROPIC_API_KEY (required), APP_TOKEN (optional shared token)
// Vars:    MODEL (required, a current Claude model id), ALLOWED_ORIGIN (optional)

const LANGS = {
  ar: "Arabic", en: "English", fr: "French", es: "Spanish (Spain)",
  es_MX: "Mexican Spanish", tr: "Turkish", hi: "Hindi", zh: "Simplified Chinese",
  id: "Indonesian", de: "German", it: "Italian", nl: "Dutch",
  nb: "Norwegian Bokmål", pl: "Polish", pt: "European Portuguese",
  pt_BR: "Brazilian Portuguese", ro: "Romanian", vi: "Vietnamese",
};

const RULES =
  "You are a professional resume writer. Never invent employers, dates, titles, " +
  "degrees or figures. If a number would help but is unknown, use a placeholder " +
  "such as [X%]. Output plain text only: no markdown, no headings with #, no quotes " +
  "around the answer, no preface or explanation.";

function buildPrompt(b) {
  const lang = LANGS[b.lang] || "English";
  const target = LANGS[b.target] || lang;
  const resume = JSON.stringify(b.resume || {});
  const job = String(b.job || "").slice(0, 8000);
  const input = String(b.input || "").slice(0, 8000);

  switch (b.task) {
    case "summary":
      return {
        maxTokens: 400,
        system: RULES,
        user: `Write a professional resume summary of 2 to 4 sentences in ${lang}.` +
          (job ? ` Tailor it to this job description:\n${job}\n` : "") +
          (input ? `Current summary to build on:\n${input}\n` : "") +
          `Resume data:\n${resume}`,
      };
    case "improve":
      return {
        maxTokens: 700,
        system: RULES,
        user: "Rewrite the following resume text with stronger, more concrete wording. " +
          "Keep the same language as the text, keep the meaning, keep one item per line, " +
          `and return the same number of lines.\n\n${input}`,
      };
    case "bullets":
      return {
        maxTokens: 500,
        system: RULES,
        user: `Write 5 resume bullet points in ${lang}, one per line, each starting with a ` +
          `strong action verb, for this role: ${input}. Use the resume data only as context:\n${resume}`,
      };
    case "skills":
      return {
        maxTokens: 400,
        system: RULES,
        user: `Suggest 15 relevant skills in ${target}, one per line, for this person. ` +
          "Keep tool and product names in their original form. Exclude skills already listed.\n" +
          `Resume data:\n${resume}`,
      };
    case "translate":
      return {
        maxTokens: 4000,
        system: RULES + " For this task output ONLY valid JSON.",
        user: `Translate the text values of this resume into ${target}. Return JSON with exactly ` +
          'these keys: jobTitle, summary, experiences (array of {title, description}), education ' +
          "(array of {degree, description}), skills (array of strings), languages (array of {name}), " +
          "projects (array of {name, description}). Keep the same array lengths and order. " +
          `Keep proper names and tool names unchanged.\n${resume}`,
      };
    case "jobMatch":
      return {
        maxTokens: 900,
        system: RULES,
        user: `Compare this resume with the job description. Answer in ${lang} with: the match ` +
          "percentage, the matched keywords, the missing keywords, and 3 specific edits.\n" +
          `Job description:\n${job}\n\nResume data:\n${resume}`,
      };
    case "coverLetter":
      return {
        maxTokens: 900,
        system: RULES,
        user: `Write a cover letter of at most 250 words in ${lang} for this person` +
          (job ? ` applying to this job:\n${job}\n` : ".\n") + `Resume data:\n${resume}`,
      };
    case "review":
      return {
        maxTokens: 900,
        system: RULES,
        user: `Review this resume. Answer in ${lang} with a score out of 100 on the first line, ` +
          `then the 5 most valuable improvements, one per line.\nResume data:\n${resume}`,
      };
    default:
      return null;
  }
}

const json = (obj, status, headers) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json", ...headers },
  });

export default {
  async fetch(request, env) {
    const cors = {
      "access-control-allow-origin": env.ALLOWED_ORIGIN || "*",
      "access-control-allow-headers": "content-type, x-app-token",
      "access-control-allow-methods": "POST, OPTIONS",
    };
    if (request.method === "OPTIONS") return new Response(null, { headers: cors });
    if (request.method !== "POST") return json({ error: "method" }, 405, cors);
    if (env.APP_TOKEN && request.headers.get("x-app-token") !== env.APP_TOKEN) {
      return json({ error: "unauthorized" }, 401, cors);
    }

    const raw = await request.text();
    if (raw.length > 60000) return json({ error: "too large" }, 413, cors);

    let body;
    try {
      body = JSON.parse(raw);
    } catch {
      return json({ error: "bad json" }, 400, cors);
    }

    const built = buildPrompt(body);
    if (!built) return json({ error: "bad task" }, 400, cors);

    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: env.MODEL,
        max_tokens: built.maxTokens,
        system: built.system,
        messages: [{ role: "user", content: built.user }],
      }),
    });
    if (!res.ok) return json({ error: "upstream", status: res.status }, 502, cors);

    const data = await res.json();
    const text = (data.content || [])
      .filter((p) => p.type === "text")
      .map((p) => p.text)
      .join("")
      .trim();
    return json({ text }, 200, cors);
  },
};
