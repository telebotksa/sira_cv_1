# AI proxy (Cloudflare Worker)

The app never contains a model API key. It calls this small server, which holds the key and
builds the prompts for every AI feature (summary, improve, bullets, skills, translate,
job match, cover letter, review).

Without a server the app still works in **basic mode** (offline templates and keyword matching).
Translation of a whole resume needs the server.

## Deploy (about 10 minutes)

1. Create a free Cloudflare account and install Wrangler: `npm i -g wrangler`, then `wrangler login`.
2. In an empty folder put `worker.js` from this directory and a `wrangler.toml`:

   ```toml
   name = "cv-maker-ai"
   main = "worker.js"
   compatibility_date = "2025-01-01"

   [vars]
   MODEL = "PUT-A-CURRENT-CLAUDE-MODEL-ID-HERE"   # see the model list in Anthropic's docs
   ALLOWED_ORIGIN = "https://YOUR-USER.github.io"  # your web app origin; use * while testing
   ```

3. Add the secrets:

   ```bash
   wrangler secret put ANTHROPIC_API_KEY
   wrangler secret put APP_TOKEN        # optional; any random string
   ```

4. `wrangler deploy` prints the URL, for example `https://cv-maker-ai.YOURNAME.workers.dev`.

## Connect the app

- **GitHub build:** repository Settings, Secrets and variables, Actions, Variables. Add
  `AI_ENDPOINT` with the worker URL. The workflow passes it to the build.
- **Local run:** `flutter run --dart-define=AI_ENDPOINT=https://...workers.dev`
- **At runtime:** Settings, "AI server address".

If you set `APP_TOKEN`, also pass `--dart-define=AI_TOKEN=the-same-string`. Note that a token
inside an app can be extracted, so treat it as a speed bump, not as security.

## Protect your bill

- The app limits free users to 5 remote AI requests a day, but that limit lives on the device
  and can be bypassed. Add a server-side limit before public launch: Cloudflare rate limiting
  rules, or Workers KV counters keyed by IP or by a signed user id.
- Verify the premium entitlement on the server (for example with the RevenueCat REST API)
  before granting the higher limit.
- Set a monthly spend cap in your model provider's console.
- Do not log resume contents; they are personal data. Mention AI processing in your privacy policy.

## Contract

`POST` JSON `{task, lang, target, input, job, resume}`, answer `200 {"text": "..."}`.
`task` is one of `summary, improve, bullets, skills, translate, jobMatch, coverLetter, review`.
For `translate` the text must be JSON (see `worker.js`).
