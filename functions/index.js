const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions/v2");
const {defineSecret} = require("firebase-functions/params");

admin.initializeApp();

setGlobalOptions({maxInstances: 10, region: "europe-west1"});

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

/**
 * Validates a Firestore-style calendar id `yyyy-mm-dd`.
 * @param {unknown} v Raw value from the client.
 * @return {string|null}
 */
function clampDateId(v) {
  if (typeof v !== "string") return null;
  // yyyy-mm-dd
  if (!/^\d{4}-\d{2}-\d{2}$/.test(v)) return null;
  return v;
}

const MONTH_NAMES_EN = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
];

const MONTH_NAMES_RU = [
  "января", "февраля", "марта", "апреля", "мая", "июня",
  "июля", "августа", "сентября", "октября", "ноября", "декабря",
];

/**
 * @param {string} dateId `yyyy-mm-dd`
 * @param {"ru"|"en"|string} [responseLanguage]
 * @return {string}
 */
function formatDateIdHuman(dateId, responseLanguage = "en") {
  const parts = dateId.split("-");
  if (parts.length !== 3) return dateId;
  const y = Number(parts[0]);
  const m = Number(parts[1]);
  const d = Number(parts[2]);
  if (!y || !m || !d || m < 1 || m > 12) return dateId;
  if (responseLanguage === "ru") {
    return `${d} ${MONTH_NAMES_RU[m - 1]} ${y}`;
  }
  return `${d} ${MONTH_NAMES_EN[m - 1]} ${y}`;
}

/**
 * Dominant language of journal text for the model reply.
 * @param {Array<{text: string}>} entries
 * @return {"ru"|"en"|"uk"|"de"|"fr"|"es"|"en"}
 */
function detectResponseLanguage(entries) {
  const counts = {cyrillic: 0, latin: 0};
  for (const e of entries) {
    const t = (e.text || "").trim();
    for (const ch of t) {
      if (/\p{Script=Cyrillic}/u.test(ch)) counts.cyrillic++;
      else if (/\p{Script=Latin}/u.test(ch)) counts.latin++;
    }
  }
  if (counts.cyrillic > counts.latin && counts.cyrillic > 15) return "ru";
  if (counts.latin > 0) return "en";
  return "en";
}

/**
 * @param {"ru"|"en"|"uk"|"de"|"fr"|"es"} code
 * @return {string}
 */
function languageNameForPrompt(code) {
  const map = {
    ru: "Russian",
    en: "English",
    uk: "Ukrainian",
    de: "German",
    fr: "French",
    es: "Spanish",
  };
  return map[code] || "English";
}

/**
 * Few-shot style anchor (fictional week — tone only, not facts to copy).
 * @param {"ru"|"en"|string} responseLanguage
 * @return {string[]}
 */
function fewShotStyleBlock(responseLanguage) {
  if (responseLanguage === "ru") {
    return [
      "STYLE EXAMPLE (illustration only — do NOT copy these facts into your " +
        "reply; match the tone and paragraph flow for the real entries below):",
      "",
      "[Sample entries for style]",
      "Day: 6 мая 2026 | Stars: 3/5 | Entry: Устал после работы, вечером " +
        "просто лежал.",
      "Day: 8 мая 2026 | Stars: 2/5 | Entry: Тревожно из‑за дедлайна, " +
        "мало спал.",
      "Day: 10 мая 2026 | Stars: 5/5 | Entry: Прогулка с другом, " +
        "наконец отпустило.",
      "",
      "[Sample good reply in Russian — imitate this voice, not these events]",
      "За эту неделю у тебя были настоящие «качели» — от тихого вечера " +
        "после работы до тревоги из‑за дедлайна, и потом заметный подъём " +
        "после прогулки с другом. В среднем настроение около 3,5 из 5: не " +
        "провал, но и не лёгкая неделя. Середина недели выглядела самой " +
        "тяжёлой — ты сам писал про сон и дедлайн, и это звучит " +
        "выматывающе.",
      "",
      "Хорошо, что в конце недели ты нашёл опору в простых вещах — прогулка " +
        "и разговор реально сдвинули день в плюс. На следующую неделю можно " +
        "мягко попробовать: в дни с высокой нагрузкой — короткая прогулка " +
        "или звонок близкому человеку, без цели «исправить» настроение, " +
        "просто чтобы не оставаться один на один с тревогой.",
    ];
  }
  return [
    "STYLE EXAMPLE (illustration only — do NOT copy these facts; match tone " +
      "for the real entries below):",
    "",
    "[Sample entries]",
    "Day: 6 May 2026 | Stars: 3/5 | Entry: Tired after work, just rested.",
    "Day: 8 May 2026 | Stars: 2/5 | Entry: Anxious about a deadline, " +
      "slept poorly.",
    "Day: 10 May 2026 | Stars: 5/5 | Entry: Walk with a friend — " +
      "finally felt lighter.",
    "",
    "[Sample good reply]",
    "This week had real ups and downs: quiet evenings after work, a rough " +
      "middle around the deadline, then a clear lift after time with a " +
      "friend. Your average mood sits around 3.5 out of 5 — not a disaster, " +
      "but not an easy stretch either. The middle of the week sounds like it " +
      "cost you the most; you mentioned poor sleep and pressure, and that's " +
      "worth taking seriously without beating yourself up.",
    "",
    "What stood out positively is how something simple — a walk and a " +
      "conversation — shifted the end of the week. For the days ahead, you " +
      "might try one small anchor on heavy days: a ten-minute walk or a " +
      "message to someone you trust, not to \"fix\" mood, just so stress " +
      "doesn't pile up alone.",
  ];
}

/**
 * Light cleanup so UI / demo video never shows markdown report junk.
 * @param {string} text
 * @return {string}
 */
function sanitizeAiSummary(text) {
  let s = String(text || "").trim();
  s = s.replace(/\*\*/g, "");
  s = s.replace(/^\s*Overall:\s*/gim, "");
  s = s.replace(/^\s*In summary:\s*/gim, "");
  s = s.replace(/^\s*Key takeaways?:\s*/gim, "");
  s = s.replace(/\n{3,}/g, "\n\n");
  return s.trim();
}

/**
 * Builds the Gemini prompt for period analysis.
 * @param {{fromDateId: string, toDateId: string, avgRating: number,
 *   entries: Array<{dateId: string, text: string, rating: number}>,
 *   responseLanguage: string}} args
 * @return {string} Full prompt text.
 */
function buildPrompt({
  fromDateId,
  toDateId,
  avgRating,
  entries,
  responseLanguage,
}) {
  const lang = languageNameForPrompt(responseLanguage);
  const periodFrom = formatDateIdHuman(fromDateId, responseLanguage);
  const periodTo = formatDateIdHuman(toDateId, responseLanguage);
  const wordHint =
    responseLanguage === "ru" ?
      "about 180–320 words" :
      "about 160–280 words";

  const lines = [
    "You are a personal journal companion — like a calm, attentive friend " +
      "who read the diary with care. You are NOT: a corporate analyst, a " +
      "therapist making diagnoses, a life coach with a program, or a report " +
      "with numbered sections.",
    "",
    "VOICE & LANGUAGE",
    `- Write the entire reply in ${lang} only. ` +
      `Every sentence must be in ${lang}.`,
    "- Address the person directly (natural ты in Russian; " +
      "\"you\" in English).",
    "- Write as if speaking to one person: short paragraphs, concrete " +
      "details from their entries.",
    "- When entries mention grief, loss, fear, loneliness, or acute stress, " +
      "include one sincere sentence of empathy tied to what they wrote — " +
      "not generic platitudes.",
    "- When they share something genuinely good, name it briefly and warmly.",
    "- End with 1–2 gentle, optional ideas for the next week or month — " +
      "like a calm mentor, not a coach.",
    `- Length: ${wordHint} — personal, not a lecture.`,
    "",
    "BANNED (never use)",
    "- \"Overall:\", \"In summary:\", \"Key takeaways\", \"Notable changes\"",
    "- Numbered sections (1) 2) 3)) or markdown bold (**)",
    "- Empty empathy: \"I understand how you feel\", \"Stay strong\"",
    "- Invented events, people, or emotions not in the entries",
    "",
    "FACTS",
    "- Use only information from the journal entries below.",
    "- If something is unclear, say you are not sure instead of guessing.",
    "- Star ratings (1–5) are the main mood signal; mention the average " +
      "and notable day-to-day shifts.",
    "- Dates in your reply: natural form only " +
      "(e.g. \"13 May 2026\" or \"13 мая 2026\"), never yyyy-mm-dd.",
    "",
    ...fewShotStyleBlock(responseLanguage),
    "",
    `Period covered: ${periodFrom} through ${periodTo}`,
    `Average star rating (computed): ${avgRating.toFixed(2)} / 5`,
  ];

  if (entries.length === 1) {
    lines.push("");
    lines.push(
        "SCOPE: Only one journal entry exists in this period. Write a deep, " +
          "tone-appropriate reflection on that single day — do NOT describe " +
          "a multi-day arc, \"the middle of the week\", or day-to-day shifts " +
          "you cannot see in the data. You may reference what they wrote " +
          "about earlier feelings if they mention them inside that entry.",
    );
  }

  lines.push("");
  lines.push("Journal entries (source material — use ONLY these facts):");

  for (const e of entries) {
    const text = (e.text || "").trim();
    const clipped = text.length > 2400 ? text.slice(0, 2400) + "…" : text;
    lines.push("");
    lines.push(`Day: ${formatDateIdHuman(e.dateId, responseLanguage)}`);
    lines.push(`Stars: ${e.rating ?? 0} / 5`);
    lines.push(`Entry: ${clipped.length ? clipped : "(no text)"}`);
  }

  lines.push("");
  lines.push(
      "Now write the period reflection for this person in " + lang + " only. " +
      "Copy the paragraph flow from the STYLE EXAMPLE, but adapt the tone " +
      "to the user's selected Friendly/Critic setting if present. Use ONLY " +
      "facts from \"Journal entries\" above. If the week was mixed, say so " +
      "honestly. If there is only one entry, reflect on that day in depth " +
      "without inventing other days. Do not pad with generic advice.",
  );

  return lines.join("\n");
}

/**
 * Reads `users/{uid}` onboarding + custom prompt for Gemini.
 * @param {FirebaseFirestore.DocumentData|undefined} data
 * @return {string}
 */
function buildUserAiContextBlock(data) {
  if (!data) return "";
  const lines = [
    "User profile (from onboarding / settings — " +
      "respect privacy, do not echo verbatim unless helpful):",
  ];
  const tone = String(data.aiTone || "friendly").trim();
  if (tone === "critic") {
    lines.push("");
    lines.push("AI response tone selected by the user: Critic.");
    lines.push(
        "- Be direct, observant, and pattern-focused. Name avoidance, " +
          "repeated loops, or contradictions when the entries support it.",
    );
    lines.push(
        "- Do not be harsh, sarcastic, judgmental, or shaming. The critique " +
          "must feel useful and grounded, not punishing.",
    );
    lines.push(
        "- Prefer clear sentences and 1–2 practical next steps over comfort " +
          "phrases. Still acknowledge genuinely hard moments.",
    );
  } else {
    lines.push("");
    lines.push("AI response tone selected by the user: Friendly.");
    lines.push(
        "- Be warm, gentle, validating, and encouraging while staying " +
          "specific to the entries.",
    );
    lines.push(
        "- Prefer soft suggestions and supportive framing over direct " +
          "challenge.",
    );
  }

  const open = data.onboardingOpenAnswers || {};
  let any = false;
  for (let i = 1; i <= 7; i++) {
    const k = "open" + i;
    const v = String(open[k] || "").trim();
    if (v) {
      any = true;
      lines.push(`- ${k}: ${v}`);
    }
  }
  const custom = String(data.aiCustomPrompt || "").trim();
  if (custom) {
    any = true;
    lines.push("User extra instructions for the assistant:");
    lines.push(custom);
    lines.push(
        "If user instructions conflict with the selected tone or forbid " +
          "using only entries, prefer selected tone and source facts.",
    );
  }
  const quiz = data.quizAnswers;
  if (!any && quiz && typeof quiz === "object") {
    lines.push("Legacy quiz (multiple-choice indices only):");
    lines.push(JSON.stringify(quiz));
  }
  lines.push("");
  return lines.join("\n");
}

/**
 * @param {string} uid
 * @return {Promise<string>}
 */
async function loadUserAiContext(uid) {
  const snap = await admin.firestore().collection("users").doc(uid).get();
  return buildUserAiContextBlock(snap.data());
}

/**
 * Calls Gemini REST API (v1beta generateContent).
 * @param {object} args Call options.
 * @param {string} args.apiKey Gemini API key.
 * @param {string} args.model Model id.
 * @param {string} args.prompt Full prompt text.
 * @param {number} [args.temperature] Sampling temperature.
 * @return {Promise<string>}
 */
async function callGemini({apiKey, model, prompt, temperature = 0.78}) {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/` +
    `${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(
        apiKey,
    )}`;

  const res = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      contents: [{role: "user", parts: [{text: prompt}]}],
      generationConfig: {
        temperature,
        maxOutputTokens: 1400,
      },
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Gemini HTTP ${res.status}: ${body}`);
  }

  const json = await res.json();
  const text =
    json?.candidates?.[0]?.content?.parts?.map((p) => p.text).join("") ?? "";
  return String(text).trim();
}

exports.analyzePeriod = onCall(
    {
      secrets: [GEMINI_API_KEY],
      // No App Check in the Flutter app; keep callables callable if project
      // defaults would enforce App Check.
      enforceAppCheck: false,
    },
    async (req) => {
      if (!req.auth) {
        throw new HttpsError("unauthenticated", "Sign in required.");
      }

      const uid = req.auth.uid;
      const data = req.data ?? {};

      const periodId = typeof data.periodId === "string" ? data.periodId : null;
      const periodType =
      data.periodType === "week" || data.periodType === "month" ?
        data.periodType :
        null;
      const fromDateId = clampDateId(data.fromDateId);
      const toDateId = clampDateId(data.toDateId);
      const force = data.force === true;

      if (!periodId || !periodType || !fromDateId || !toDateId) {
        throw new HttpsError("invalid-argument", "Bad request payload.");
      }

      const analysisRef = admin
          .firestore()
          .collection("users")
          .doc(uid)
          .collection("period_analyses")
          .doc(periodId);

      const existing = await analysisRef.get();
      if (existing.exists && !force) {
        return {ok: true, skipped: true};
      }

      // Rate limit: at most 1 regenerate per 30 seconds per period.
      const lastAt = existing.exists ? existing.get("createdAt") : null;
      if (force && lastAt && lastAt.toDate) {
        const ms = Date.now() - lastAt.toDate().getTime();
        if (ms < 30_000) {
          throw new HttpsError(
              "resource-exhausted",
              "Please wait a bit before regenerating.",
          );
        }
      }

      const entriesSnap = await admin
          .firestore()
          .collection("users")
          .doc(uid)
          .collection("entries")
          .where("date", ">=", fromDateId)
          .where("date", "<=", toDateId)
          .orderBy("date")
          .get();

      const entries = entriesSnap.docs.map((d) => ({
        dateId: d.get("date") || d.id,
        text: d.get("text") || "",
        rating: Number(d.get("rating") || 0),
      }));

      if (!entries.length) {
        await analysisRef.set(
            {
              periodType,
              fromDateId,
              toDateId,
              entryDateIds: [],
              avgRating: 0,
              summary: "No entries in this period.",
              model: "none",
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            {merge: true},
        );
        return {ok: true, empty: true};
      }

      const rated = entries.filter((e) => e.rating > 0);
      const avgRating =
      rated.length === 0 ?
        0 :
        rated.reduce((acc, e) => acc + e.rating, 0) / rated.length;

      const userContext = await loadUserAiContext(uid);
      const responseLanguage = detectResponseLanguage(entries);
      const basePrompt = buildPrompt({
        fromDateId,
        toDateId,
        avgRating,
        entries,
        responseLanguage,
      });
      const prompt = [basePrompt, userContext].join("\n");

      const model = "gemini-2.5-flash-lite";
      const apiKey = GEMINI_API_KEY.value();
      const temperature = force ? 0.82 : 0.78;
      const rawSummary = await callGemini({
        apiKey,
        model,
        prompt,
        temperature,
      });

      if (!rawSummary) {
        throw new HttpsError("internal", "Empty Gemini response.");
      }

      const summary = sanitizeAiSummary(rawSummary);

      await analysisRef.set(
          {
            periodType,
            fromDateId,
            toDateId,
            entryDateIds: entries.map((e) => String(e.dateId)),
            avgRating,
            summary,
            model,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
      );

      logger.info("analyzePeriod ok", {uid, periodId, periodType});
      return {ok: true};
    },
);
