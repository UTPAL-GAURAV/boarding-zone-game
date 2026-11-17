import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// ── Thresholds that trigger a notification when crossed downward ──────────────
// 10, then every 50 up to 500. Ordered outermost-first so a big drop in one
// cron run notifies at the widest bracket; inner thresholds fire on later runs.
const THRESHOLDS: number[] = (() => {
  const t = [10];
  for (let i = 50; i <= 500; i += 50) t.push(i);
  return t.sort((a, b) => b - a); // [500, 450, ..., 50, 10]
})();

// ── Notification copy per threshold ──────────────────────────────────────────

function notifCopy(
  threshold: number,
  aircraftName: string,
  currentRank: number,
): { title: string; body: string } {
  const rank = `#${currentRank}`;
  switch (threshold) {
    case 10:
      return {
        title: "Your Top 10 seat just got stolen ✈️",
        body: `You're ${rank} on ${aircraftName}. Someone's in your spot. Take it back.`,
      };
    case 50:
      return {
        title: "The leaderboard moved without you ✈️",
        body: `You're ${rank} on ${aircraftName}. Come back and remind them who runs this cabin.`,
      };
    default:
      // Every 100+ bracket reuses the same message pattern — feels urgent at any depth.
      return {
        title: `Sliding down fast — you're ${rank} ✈️`,
        body: `You've dropped out of the top ${threshold} on ${aircraftName}. Don't let the gap grow.`,
      };
  }
}

// ── Slug → display name (e.g. "cessna-grand-caravan-ex" → "Cessna Grand Caravan EX") ──

const UPPERCASE_TOKENS = new Set(["ex", "erj", "crj", "atc", "xlr", "neo"]);

function slugToName(slug: string): string {
  return slug
    .split("-")
    .map((word) =>
      UPPERCASE_TOKENS.has(word)
        ? word.toUpperCase()
        : word.charAt(0).toUpperCase() + word.slice(1)
    )
    .join(" ");
}

// ── FCM HTTP v1 via a service-account access token ───────────────────────────

async function getFcmAccessToken(): Promise<string> {
  const sa = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
  const now = Math.floor(Date.now() / 1000);
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = btoa(
    JSON.stringify({
      iss: sa.client_email,
      sub: sa.client_email,
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
    }),
  );
  const sigInput = `${header}.${payload}`;

  const pemKey = sa.private_key.replace(/\\n/g, "\n");
  const keyData = pemKey
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(sigInput),
  );
  const jwt =
    `${sigInput}.${btoa(String.fromCharCode(...new Uint8Array(sig)))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  const json = await res.json();
  return json.access_token as string;
}

async function sendFcm(
  token: string,
  accessToken: string,
  projectId: string,
  title: string,
  body: string,
) {
  await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          android: { priority: "normal" },
        },
      }),
    },
  );
}

// ── Main handler ─────────────────────────────────────────────────────────────

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const projectId = Deno.env.get("FIREBASE_PROJECT_ID")!;
  const accessToken = await getFcmAccessToken();

  // Fetch all players who have an fcm_token
  const { data: players } = await supabase
    .from("profiles")
    .select("id, fcm_token")
    .not("fcm_token", "is", null);

  if (!players?.length) return new Response("no players", { status: 200 });

  for (const player of players) {
    // Get all aircraft this player has a score for
    const { data: scores } = await supabase
      .from("leaderboard")
      .select("aircraft_id, best_milliseconds")
      .eq("player_id", player.id);

    if (!scores?.length) continue;

    for (const score of scores) {
      // Count players strictly better to derive rank
      const { count } = await supabase
        .from("leaderboard")
        .select("player_id", { count: "exact", head: true })
        .eq("aircraft_id", score.aircraft_id)
        .lt("best_milliseconds", score.best_milliseconds);

      const currentRank = (count ?? 0) + 1;

      // Read existing snapshot
      const { data: snap } = await supabase
        .from("rank_snapshots")
        .select("last_rank, last_notified_threshold")
        .eq("player_id", player.id)
        .eq("aircraft_id", score.aircraft_id)
        .maybeSingle();

      const prevRank: number = snap?.last_rank ?? currentRank;
      // last_notified_threshold: the threshold the player last dropped past,
      // or null if never notified. Reset to null when they climb back inside
      // that threshold so future drops re-trigger the notification.
      const lastNotifiedThreshold: number | null =
        snap?.last_notified_threshold ?? null;

      // If the player climbed back inside a threshold they were previously
      // notified for, clear it so the next drop fires again.
      const clearedThreshold =
        lastNotifiedThreshold !== null && currentRank <= lastNotifiedThreshold
          ? null
          : lastNotifiedThreshold;

      // Find the outermost threshold newly crossed downward since last snapshot.
      // THRESHOLDS is ordered [500, 450, ..., 50, 10] so we report the widest bracket first.
      let crossed: number | null = null;
      for (const t of THRESHOLDS) {
        if (currentRank > t && prevRank <= t && clearedThreshold !== t) {
          crossed = t;
          break;
        }
      }

      // Upsert snapshot regardless of whether we notified
      await supabase.from("rank_snapshots").upsert(
        {
          player_id: player.id,
          aircraft_id: score.aircraft_id,
          last_rank: currentRank,
          last_notified_threshold: crossed ?? clearedThreshold,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "player_id,aircraft_id" },
      );

      if (crossed && player.fcm_token) {
        const aircraftName = slugToName(score.aircraft_id);
        const { title, body } = notifCopy(crossed, aircraftName, currentRank);
        await sendFcm(player.fcm_token, accessToken, projectId, title, body);
      }
    }
  }

  return new Response("done", { status: 200 });
});
