import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import type { ClientBase } from "pg";
import type { Question } from "@/types/game";

/**
 * Database maintenance helpers used by `npm run db:*` scripts and the
 * PostgreSQL integration tests. Never imported by the web app.
 */

// Scripts and tests run from the project root.
const ROOT = process.cwd();
export const MIGRATIONS_DIR = path.join(ROOT, "supabase", "migrations");
export const LOCAL_BOOTSTRAP = path.join(ROOT, "supabase", "tests", "local_bootstrap.sql");

/** Applies pending migrations in filename order, recording them in a tracking table. */
export async function applyMigrations(client: ClientBase): Promise<string[]> {
  await client.query(
    "create table if not exists public.schema_migrations (name text primary key, applied_at timestamptz not null default now())",
  );
  await client.query("alter table public.schema_migrations enable row level security");
  const { rows } = await client.query<{ name: string }>("select name from public.schema_migrations");
  const done = new Set(rows.map((r) => r.name));
  const applied: string[] = [];
  for (const file of readdirSync(MIGRATIONS_DIR).filter((f) => f.endsWith(".sql")).sort()) {
    if (done.has(file)) continue;
    await client.query("begin");
    try {
      await client.query(readFileSync(path.join(MIGRATIONS_DIR, file), "utf8"));
      await client.query("insert into public.schema_migrations (name) values ($1)", [file]);
      await client.query("commit");
      applied.push(file);
    } catch (err) {
      await client.query("rollback");
      throw new Error(`Migration ${file} failed: ${(err as Error).message}`);
    }
  }
  return applied;
}

/** Emulates Supabase roles and the auth schema on plain PostgreSQL. Local/CI only. */
export async function applyLocalBootstrap(client: ClientBase): Promise<void> {
  await client.query(readFileSync(LOCAL_BOOTSTRAP, "utf8"));
}

/** Inserts questions that do not exist yet; existing rows (possibly edited by admins) are left untouched. */
export async function seedQuestions(client: ClientBase, questions: readonly Question[]): Promise<number> {
  let inserted = 0;
  for (const q of questions) {
    const r = await client.query(
      `insert into public.questions (id, translation_key, locale, category_id, difficulty, text, options, correct_index,
         explanation, source_kind, source_reference, review_status, ranked_eligible, version, created_at)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)
       on conflict (id) do nothing`,
      [q.id, q.translationKey, q.locale, q.category, q.difficulty, q.text, q.options, q.correctIndex, q.explanation,
        q.source.kind, q.source.reference, q.reviewStatus, q.rankedEligible, q.version, q.createdAt],
    );
    inserted += r.rowCount ?? 0;
  }
  return inserted;
}
