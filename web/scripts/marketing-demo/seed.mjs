// The marketing demo dataset (LIF-120, docs/landing_page/72 W12).
//
// Seeds a LOCAL backend (:8080) and chat service (:8081) with one coherent demo "product": a personal trainer with five
// clients, a six-week strength programme assigned to the main client, her weigh-ins, workouts and meals, and a chat thread.
// It is what `capture.mjs` photographs for the marketing site, so the pictures show one product with one set of names.
//
// Two parallel universes - Hungarian and English - because the pages are bilingual and a capture of an English UI full of
// Hungarian exercise names and chat messages would not be a believable product: each has its own trainer and clients (the
// clients keep their Hungarian names in both) and its own texts. Each user's `language` setting is set to match.
//
// Re-runnable: accounts, exercises, templates, programme, assignment and data are created only when missing. Needs the
// Postgres on :5432 (ROLE_TRAINER has no grant API, so it is inserted - same as the e2e specs). Never point it at a shared
// database: it registers accounts.
//
//   node scripts/marketing-demo/seed.mjs            # both universes
//   node scripts/marketing-demo/seed.mjs hu         # one
import pg from "pg";

const API = process.env.LIFEY_API ?? "http://localhost:8080/api/v1";
const CHAT = process.env.LIFEY_CHAT ?? "http://localhost:8081/api/v1";
const DB = { host: "localhost", port: 5432, database: "lifey", user: "lifey", password: "lifey" };
export const PASSWORD = "LifeyDemo123!";

export const UNIVERSES = {
  hu: {
    language: "HUNGARIAN",
    trainer: { email: "peter.kovacs@example.com", firstName: "Péter", lastName: "Kovács" },
    clients: [
      { key: "anna", email: "anna.szabo@example.com", firstName: "Anna", lastName: "Szabó" },
      { key: "mark", email: "mark.toth@example.com", firstName: "Márk", lastName: "Tóth" },
      { key: "reka", email: "reka.nagy@example.com", firstName: "Réka", lastName: "Nagy" },
      { key: "lilla", email: "lilla.horvath@example.com", firstName: "Lilla", lastName: "Horváth" },
    ],
    invited: { email: "david.kiss@example.com" },
    exercises: { squat: "Guggolás", bench: "Fekvenyomás", row: "Evezés", plank: "Plank", deadlift: "Felhúzás" },
    templates: { a: "Erő 5×5 — A", b: "Erő 5×5 — B" },
    program: "Erő 5×5",
    foods: {
      oats: "Zabpehely", yogurt: "Görög joghurt", banana: "Banán", chicken: "Csirkemell", rice: "Rizs",
      broccoli: "Brokkoli", eggs: "Tojás",
    },
    chat: [
      ["client", "Szia Péter! A mai guggolás 82,5 kg-mal ment, de az utolsó széria nehéz volt."],
      ["trainer", "Szuper munka! Ha a technika végig tiszta maradt, jövő héten mehet 85 kg."],
      ["client", "Tiszta volt, csak a mélységet figyeltem. Pihenőnapon sétáljak vagy teljes pihenő legyen?"],
      ["trainer", "Egy könnyű séta jót tesz. Holnap küldöm a heti összefoglalót is. 💪"],
    ],
  },
  en: {
    language: "ENGLISH",
    trainer: { email: "peter.kovacs@example.org", firstName: "Péter", lastName: "Kovács" },
    clients: [
      { key: "anna", email: "anna.szabo@example.org", firstName: "Anna", lastName: "Szabó" },
      { key: "mark", email: "mark.toth@example.org", firstName: "Márk", lastName: "Tóth" },
      { key: "reka", email: "reka.nagy@example.org", firstName: "Réka", lastName: "Nagy" },
      { key: "lilla", email: "lilla.horvath@example.org", firstName: "Lilla", lastName: "Horváth" },
    ],
    invited: { email: "david.kiss@example.org" },
    exercises: { squat: "Squat", bench: "Bench Press", row: "Barbell Row", plank: "Plank", deadlift: "Deadlift" },
    templates: { a: "Strength 5×5 — A", b: "Strength 5×5 — B" },
    program: "Strength 5×5",
    foods: {
      oats: "Oats", yogurt: "Greek yogurt", banana: "Banana", chicken: "Chicken breast", rice: "Rice",
      broccoli: "Broccoli", eggs: "Eggs",
    },
    chat: [
      ["client", "Hi Péter! Today's squats went at 82.5 kg, but the last set was heavy."],
      ["trainer", "Great work! If the form stayed clean all the way, 85 kg is on for next week."],
      ["client", "It was clean, I was watching my depth. Should I walk on the rest day or fully rest?"],
      ["trainer", "An easy walk helps. I'll send the weekly summary tomorrow too. 💪"],
    ],
  },
};

const FOOD_FACTS = {
  oats: [389, 16.9, 66, 6.9], yogurt: [59, 10, 3.6, 0.4], banana: [89, 1.1, 23, 0.3], chicken: [165, 31, 0, 3.6],
  rice: [130, 2.7, 28, 0.3], broccoli: [34, 2.8, 7, 0.4], eggs: [155, 13, 1.1, 11],
};

async function call(method, base, path, token, body, { allow = [] } = {}) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok && !allow.includes(res.status)) throw new Error(`${method} ${path} -> ${res.status}: ${text.slice(0, 300)}`);
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* not JSON */ }
  return { status: res.status, ok: res.ok, json };
}

const get = (path, token) => call("GET", API, path, token).then((r) => r.json);
const post = (path, token, body, opts) => call("POST", API, path, token, body, opts);

async function registerOrLogin({ email, firstName, lastName }) {
  await post("/auth/register", null, { email, password: PASSWORD, firstName, lastName }, { allow: [400, 409, 422, 429] });
  const login = await post("/auth/login", null, { email, password: PASSWORD });
  const me = await get("/me", login.json.accessToken).catch(() => null);
  return { token: login.json.accessToken, id: me?.id ?? login.json.user?.id ?? null, email, firstName, lastName };
}

async function userId(db, email) {
  const r = await db.query("select id from users where email = $1", [email]);
  return Number(r.rows[0].id);
}

async function grantTrainer(db, id) {
  await db.query("insert into user_roles (user_id, role) values ($1, 'ROLE_TRAINER') on conflict do nothing", [id]);
}

async function setLanguage(token, language) {
  const settings = await get("/settings", token);
  await call("PUT", API, "/settings", token, { ...settings, language, theme: "SYSTEM" });
}

async function ensureExercises(token, names) {
  const have = await get("/exercises", token);
  const byName = new Map(have.map((e) => [e.name, e.id]));
  const categories = { squat: "QUADS", bench: "CHEST", row: "BACK", plank: "ABS", deadlift: "HAMSTRINGS" };
  for (const [key, name] of Object.entries(names)) {
    if (!byName.has(name)) {
      const created = await post("/exercises", token, { name, category: categories[key] ?? null, defaultRestSeconds: 120 });
      byName.set(name, created.json.id);
    }
  }
  return Object.fromEntries(Object.entries(names).map(([key, name]) => [key, byName.get(name)]));
}

async function ensureTemplate(token, name, exercises) {
  const have = await get("/workout-templates", token);
  const existing = have.find((t) => t.name === name);
  if (existing) return existing.id;
  const created = await post("/workout-templates", token, { name, exercises, durationMinutes: 55 });
  return created.json.id;
}

function mondayOnOrAfterTomorrow() {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  while (d.getDay() !== 1) d.setDate(d.getDate() + 1);
  return d.toISOString().slice(0, 10);
}

const daysAgo = (n, hour = 18, minute = 0) => {
  const d = new Date();
  d.setDate(d.getDate() - n);
  d.setHours(hour, minute, 0, 0);
  return d;
};

const roundHalf = (n) => Math.round(n * 2) / 2;
const round25 = (n) => Math.round(n / 2.5) * 2.5;
const dow = (daysBack) => {
  const d = new Date();
  d.setDate(d.getDate() - daysBack);
  return d.getDay(); // 0 Sunday
};

/** A client's last `weeks` weeks of strength sessions (Mon A, Wed B, Fri A) and Saturday runs, loads creeping up. */
function sessionsFor(profile) {
  const out = [];
  const days = profile.weeks * 7;
  for (let d = days; d >= 1; d--) {
    const progress = 1 - d / days; // 0 oldest .. ~1 newest
    const day = dow(d);
    const bump = (base, gain) => round25(base + gain * progress);
    if ([1, 3, 5].includes(day) && d % 7 !== profile.skip) {
      const a = day !== 3;
      out.push({
        daysAgo: d,
        lifts: a
          ? [["squat", bump(profile.squat, profile.gain)], ["bench", bump(profile.bench, profile.gain * 0.6)], ["row", bump(profile.row, profile.gain * 0.5)]]
          : [["deadlift", bump(profile.squat + 12.5, profile.gain)], ["bench", bump(profile.bench - 2.5, profile.gain * 0.6)], ["plank", 0]],
        rpe: 6 + (d % 3),
      });
    } else if (day === 6 && profile.runs && Math.floor(d / 7) % 2 === 0) {
      out.push({ daysAgo: d, kind: "run", hour: 8 });
    }
  }
  return out;
}

async function seedClientData(client, u, ids, profile) {
  const t = client.token;
  // Weigh-ins: every third day, a gentle downward trend with a little noise.
  const weights = await get("/weights", t);
  if (!weights || weights.length < 8) {
    const days = profile.weeks * 7;
    for (let d = days; d >= 0; d -= 3) {
      const date = daysAgo(d, 8).toISOString().slice(0, 10);
      const trend = profile.weightStart - ((profile.weightStart - profile.weightNow) * (days - d)) / days;
      const noise = ((d * 37) % 7) / 20 - 0.15;
      await post("/weights", t, { date, weight: Math.round((trend + noise) * 10) / 10 }, { allow: [400, 409] });
    }
  }

  // Workouts, on the client's own copy of the exercises.
  const sessions = await get("/workout-sessions", t);
  if (!sessions || sessions.length === 0) {
    const own = await ensureExercises(t, u.exercises);
    for (const s of sessionsFor(profile)) {
      const started = daysAgo(s.daysAgo, s.hour ?? 18, (s.daysAgo % 4) * 5);
      if (s.kind === "run") {
        await post("/workout-sessions", t, {
          startedAt: started.toISOString(),
          finishedAt: new Date(started.getTime() + 34 * 60000).toISOString(),
          exerciseIds: [],
          sets: [],
          sessionKind: "CARDIO",
          activityType: "RUNNING",
          movingSeconds: 34 * 60,
          cardio: { distanceMeters: 6200 },
          rpe: 6,
        });
        continue;
      }
      const lifts = s.lifts.map(([key, kg]) => ({ id: own[key], kg, key }));
      const sets = [];
      let at = started.getTime();
      for (const lift of lifts) {
        const reps = lift.key === "plank" ? 1 : 5;
        const count = lift.key === "plank" ? 3 : 5;
        for (let i = 0; i < count; i++) {
          sets.push({ exerciseId: lift.id, reps, weight: lift.kg, performedAt: new Date(at).toISOString() });
          at += 3 * 60000;
        }
      }
      await post("/workout-sessions", t, {
        startedAt: started.toISOString(),
        finishedAt: new Date(at).toISOString(),
        exerciseIds: lifts.map((l) => l.id),
        sets,
        rpe: s.rpe ?? 7,
      });
    }
  }

  // Meals: four a day for the whole period, from the client's own foods.
  const meals = await get("/meals", t).catch(() => null);
  if (profile.meals && (!meals || meals.length === 0)) {
    const foodIds = {};
    const haveFoods = (await get("/foods?size=200", t))?.content ?? [];
    for (const [key, name] of Object.entries(u.foods)) {
      const f = haveFoods.find((x) => x.name === name);
      if (f) foodIds[key] = f.id;
      else {
        const [kcal, p, c, fat] = FOOD_FACTS[key];
        foodIds[key] = (await post("/foods", t, { name, caloriesPer100g: kcal, proteinPer100g: p, carbsPer100g: c, fatPer100g: fat, hidden: false })).json.id;
      }
    }
    const plan = [
      ["BREAKFAST", 8, [["oats", 60], ["yogurt", 150], ["banana", 100]]],
      ["LUNCH", 13, [["chicken", 180], ["rice", 250], ["broccoli", 150]]],
      ["SNACK", 16, [["yogurt", 200], ["oats", 40]]],
      ["DINNER", 19, [["eggs", 150], ["rice", 150], ["broccoli", 120]]],
    ];
    for (let day = 0; day < profile.weeks * 7; day++) {
      if (day % 9 === 5) continue; // a day or two unlogged, as in real life
      for (const [type, hour, items] of plan) {
        await post("/meals", t, {
          dateTime: daysAgo(day, hour, 15).toISOString(),
          mealType: type,
          entries: items.map(([food, grams]) => ({ foodId: foodIds[food], quantityInGrams: grams + ((day * 7) % 20) })),
        });
      }
    }
  }
}

async function seedUniverse(db, key) {
  const u = UNIVERSES[key];
  console.log(`\n== ${key}`);

  const trainerUser = await registerOrLogin(u.trainer);
  const trainerId = await userId(db, u.trainer.email);
  await grantTrainer(db, trainerId);
  // The role claim lives in the token: log in again after the grant.
  const trainer = { ...(await registerOrLogin(u.trainer)), id: trainerId };
  void trainerUser;
  await setLanguage(trainer.token, u.language);

  const clients = [];
  for (const c of u.clients) {
    const reg = await registerOrLogin(c);
    const id = await userId(db, c.email);
    const client = { ...reg, id, key: c.key };
    await setLanguage(client.token, u.language);
    const invited = await post("/trainer/invites", trainer.token, { email: c.email }, { allow: [400, 409, 422, 429] });
    const pending = (await get("/trainer-invites/pending", client.token)) ?? [];
    for (const invite of pending) {
      await post(`/trainer-invites/${invite.id}/respond`, client.token, { accept: true });
    }
    void invited;
    clients.push(client);
    console.log(`  client ${c.firstName} ${c.lastName} -> ${id}`);
  }
  // The fifth client has been invited and has not answered: a "pending" row in the trainer's list. An invite needs an
  // account to point at, so he is registered - and never responds.
  await registerOrLogin({ ...u.invited, firstName: "Dávid", lastName: "Kiss" });
  await post("/trainer/invites", trainer.token, { email: u.invited.email }, { allow: [400, 409, 422, 429] });

  // The trainer's catalogue, two templates, one six-week programme.
  const ex = await ensureExercises(trainer.token, u.exercises);
  const tA = await ensureTemplate(trainer.token, u.templates.a, [
    { exerciseId: ex.squat, targetSets: 5, targetReps: 5 },
    { exerciseId: ex.bench, targetSets: 5, targetReps: 5 },
    { exerciseId: ex.row, targetSets: 5, targetReps: 5 },
  ]);
  const tB = await ensureTemplate(trainer.token, u.templates.b, [
    { exerciseId: ex.deadlift, targetSets: 3, targetReps: 5 },
    { exerciseId: ex.bench, targetSets: 5, targetReps: 5 },
    { exerciseId: ex.plank, targetSets: 3 },
  ]);
  const programs = (await get("/trainer/programs", trainer.token)) ?? [];
  let program = programs.find((p) => p.name === u.program);
  if (!program) {
    const workouts = [];
    for (let week = 1; week <= 6; week++) {
      workouts.push({ weekNumber: week, dayOfWeek: "MONDAY", templateId: week % 2 ? tA : tB, timeOfDay: "18:00:00" });
      workouts.push({ weekNumber: week, dayOfWeek: "WEDNESDAY", templateId: week % 2 ? tB : tA, timeOfDay: "18:00:00" });
      workouts.push({ weekNumber: week, dayOfWeek: "FRIDAY", templateId: week % 2 ? tA : tB, timeOfDay: "18:00:00" });
    }
    program = (await post("/trainer/programs", trainer.token, { name: u.program, weeksCount: 6, workouts })).json;
  }
  const anna = clients.find((c) => c.key === "anna");
  const assigned = (await get(`/trainer/clients/${anna.id}/program-assignments`, trainer.token)) ?? [];
  if (assigned.length === 0) {
    await post(`/trainer/programs/${program.id}/assignments`, trainer.token, { clientId: anna.id, startDate: mondayOnOrAfterTomorrow() });
  }

  // A weekly schedule that starts today (a start in the past is refused), so "workouts this week" has occurrences to count.
  const today = new Date();
  const dayName = (n) => ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"][(today.getDay() + n) % 7];
  const scheduleEnd = new Date(today);
  scheduleEnd.setDate(scheduleEnd.getDate() + 42);
  const schedules = (await get(`/trainer/clients/${anna.id}/schedules`, trainer.token)) ?? [];
  if (schedules.length === 0) {
    await post("/trainer/schedules", trainer.token, {
      clientId: anna.id, templateId: tA, recurrence: "WEEKLY", daysOfWeek: [dayName(0), dayName(1), dayName(2)],
      timeOfDay: "18:00:00", startDate: today.toISOString().slice(0, 10), endDate: scheduleEnd.toISOString().slice(0, 10),
    }, { allow: [400, 409, 422] });
  }

  // The clients' own logs.
  const profiles = {
    anna: { weeks: 4, weightStart: 66.4, weightNow: 64.2, meals: true, squat: 72.5, bench: 57.5, row: 52.5, gain: 10, runs: true, skip: -1 },
    mark: { weeks: 3, weightStart: 92.1, weightNow: 89.6, meals: false, squat: 95, bench: 77.5, row: 72.5, gain: 7.5, runs: false, skip: 3 },
    reka: { weeks: 3, weightStart: 71.0, weightNow: 70.4, meals: false, squat: 65, bench: 47.5, row: 50, gain: 5, runs: true, skip: 2 },
    lilla: { weeks: 3, weightStart: 58.8, weightNow: 58.2, meals: false, squat: 50, bench: 37.5, row: 42.5, gain: 5, runs: true, skip: 4 },
  };
  for (const client of clients) await seedClientData(client, u, ex, profiles[client.key]);

  // Today's scheduled workout is done - the client logged it - so "workouts this week" reads 1 of 3, not 0 of 3.
  const todayIso = new Date().toISOString().slice(0, 10);
  const occurrences = (await get(`/trainer/clients/${anna.id}/scheduled-sessions?from=${todayIso}&to=${todayIso}`, trainer.token)) ?? [];
  const open = occurrences.find((o) => o.status === "UPCOMING" && o.scheduledFor === todayIso);
  if (open) {
    const own = await ensureExercises(anna.token, u.exercises);
    const lifts = [["squat", 82.5], ["bench", 65], ["row", 60]].map(([k, kg]) => ({ id: own[k], kg }));
    const started = Date.now() - 70 * 60000;
    const sets = [];
    let at = started;
    for (const lift of lifts) {
      for (let i = 0; i < 5; i++) {
        sets.push({ exerciseId: lift.id, reps: 5, weight: lift.kg, performedAt: new Date(at).toISOString() });
        at += 3 * 60000;
      }
    }
    const done = await call("PUT", API, `/workout-sessions/${open.sessionId}`, anna.token, {
      startedAt: new Date(started).toISOString(), finishedAt: new Date(at).toISOString(),
      exerciseIds: lifts.map((l) => l.id), sets, rpe: 8,
    }, { allow: [400, 404, 409, 422] });
    console.log(`  today's occurrence -> ${done.status}`);
  }

  // A chat thread with Anna.
  const conv = await call("POST", CHAT, `/chat/conversations/with-user/${anna.id}`, trainer.token, undefined);
  const conversationId = conv.json.id ?? conv.json.conversationId;
  const history = await call("GET", CHAT, `/chat/conversations/${conversationId}/messages`, trainer.token);
  const existing = history.json?.messages ?? history.json?.items ?? history.json ?? [];
  if (!Array.isArray(existing) || existing.length === 0) {
    let n = 0;
    for (const [from, body] of u.chat) {
      const token = from === "trainer" ? trainer.token : anna.token;
      await call("POST", CHAT, `/chat/conversations/${conversationId}/messages`, token, { body, clientMessageId: `demo-${key}-${++n}` });
    }
  }
  console.log(`  chat conversation ${conversationId}`);

  return { key, trainer: { email: u.trainer.email, id: trainerId }, anna: { id: anna.id, email: anna.email }, conversationId, programId: program.id };
}

export async function seedAll(keys = Object.keys(UNIVERSES)) {
  const db = new pg.Client(DB);
  await db.connect();
  try {
    const out = {};
    for (const key of keys) out[key] = await seedUniverse(db, key);
    return out;
  } finally {
    await db.end();
  }
}

if (import.meta.url === `file:///${process.argv[1].replace(/\\/g, "/")}`) {
  const keys = process.argv.slice(2).length ? process.argv.slice(2) : undefined;
  seedAll(keys).then((r) => console.log("\n" + JSON.stringify(r, null, 2))).catch((e) => {
    console.error("SEED FAILED:", e.message);
    process.exit(1);
  });
}
