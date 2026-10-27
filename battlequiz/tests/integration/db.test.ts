import { Client } from "pg";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { loadSeedQuestions } from "@/features/questions/bank";
import { applyLocalBootstrap, applyMigrations, seedQuestions } from "@/lib/db/tools";
import { createPostgresRepositories } from "@/lib/store/postgres";
import { gameplaySuite } from "./gameplay-service.test";

/**
 * PostgreSQL integration tests. They need a disposable database:
 *   TEST_DATABASE_URL=postgres://user:pass@localhost:5432/battlequiz_test npm test
 * The public schema of that database is DROPPED and recreated.
 */
const url = process.env.TEST_DATABASE_URL;
const d = url ? describe : describe.skip;

let admin: Client;

d("postgres schema", () => {
  beforeAll(async () => {
    admin = new Client({ connectionString: url });
    await admin.connect();
    await admin.query("drop schema if exists public cascade; create schema public; drop schema if exists auth cascade;");
    await applyLocalBootstrap(admin);
    await applyMigrations(admin);
    await seedQuestions(admin, loadSeedQuestions());
  });
  afterAll(async () => admin?.end());

  it("is idempotent: re-running migrations and seed changes nothing", async () => {
    expect(await applyMigrations(admin)).toEqual([]);
    expect(await seedQuestions(admin, loadSeedQuestions())).toBe(0);
  });

  it("stores every seed question", async () => {
    const { rows } = await admin.query("select count(*)::int as n from questions");
    expect(rows[0].n).toBe(loadSeedQuestions().length);
  });

  it("enforces question constraints", async () => {
    await expect(
      admin.query(`insert into questions (id, translation_key, locale, category_id, difficulty, text, options, correct_index, explanation, source_kind, source_reference)
                   values ('x', 'x', 'it', 'art', 'easy', 'Domanda di prova?', array['a','b','c'], 0, 'spiegazione', 'editorial', 'ref')`),
    ).rejects.toThrow(/check/);
    await expect(
      admin.query(`insert into questions (id, translation_key, locale, category_id, difficulty, text, options, correct_index, explanation, source_kind, source_reference, ranked_eligible)
                   values ('y', 'y', 'it', 'art', 'easy', 'Domanda di prova due?', array['a','b','c','d'], 0, 'spiegazione', 'editorial', 'ref', true)`),
    ).rejects.toThrow(/check/);
  });

  it("rejects duplicate answers at the database level", async () => {
    const id = crypto.randomUUID();
    await admin.query(`insert into matches (id, mode, status, locale, category, ruleset_version, created_by) values ($1, 'quick_play', 'ACTIVE', 'it', 'mixed', 'v1', 'guest:x')`, [id]);
    await admin.query(`insert into match_players (match_id, player_key) values ($1, 'guest:x')`, [id]);
    const ins = () =>
      admin.query(
        `insert into player_answers (match_id, player_key, question_index, selected_index, correct, timed_out, elapsed_ms, points, base_points, speed_bonus, multiplier, streak_after, answered_at)
         values ($1, 'guest:x', 0, 1, true, false, 1000, 100, 100, 0, 1, 1, now())`,
        [id],
      );
    await ins();
    await expect(ins()).rejects.toThrow(/duplicate key/);
  });

  describe("row level security", () => {
    const asRole = async <T,>(role: string, sub: string | null, fn: () => Promise<T>): Promise<T> => {
      await admin.query("begin");
      try {
        await admin.query(`set local role ${role}`);
        if (sub) await admin.query(`select set_config('request.jwt.claim.sub', $1, true)`, [sub]);
        return await fn();
      } finally {
        await admin.query("rollback");
      }
    };

    it("never lets anonymous or regular users read questions or answers", async () => {
      await expect(asRole("anon", null, () => admin.query("select correct_index from questions limit 1"))).rejects.toThrow(/permission denied/);
      // Authenticated users hold a SELECT grant (for the staff policy) but RLS filters every row out.
      const regular = await asRole("authenticated", crypto.randomUUID(), () => admin.query("select correct_index from questions"));
      expect(regular.rowCount).toBe(0);
      for (const [role, sub] of [["anon", null], ["authenticated", crypto.randomUUID()]] as const) {
        await expect(asRole(role, sub, () => admin.query("select * from match_questions limit 1"))).rejects.toThrow(/permission denied/);
        await expect(asRole(role, sub, () => admin.query("select * from player_answers limit 1"))).rejects.toThrow(/permission denied/);
      }
    });

    it("lets users read only their own profile and hides emails from public profiles", async () => {
      const [a, b] = [crypto.randomUUID(), crypto.randomUUID()];
      await admin.query("insert into auth.users (id, email) values ($1, 'a@example.com'), ($2, 'b@example.com')", [a, b]);
      await admin.query("insert into profiles (id, username) values ($1, 'alice_1'), ($2, 'bob_22')", [a, b]);
      const own = await asRole("authenticated", a, () => admin.query("select username from profiles"));
      expect(own.rows.map((r) => r.username)).toEqual(["alice_1"]);
      const pub = await asRole("anon", null, () => admin.query("select * from public_profiles"));
      expect(pub.rows.length).toBeGreaterThanOrEqual(2);
      expect(Object.keys(pub.rows[0])).not.toContain("email");
    });

    it("prevents users from granting themselves admin rights", async () => {
      const u = crypto.randomUUID();
      await admin.query("insert into auth.users (id) values ($1)", [u]);
      await expect(
        asRole("authenticated", u, () => admin.query("insert into staff_roles (user_id, role) values ($1, 'admin')", [u])),
      ).rejects.toThrow(/permission denied/);
      const isStaff = await asRole("authenticated", u, () => admin.query("select public.is_staff() as s"));
      expect(isStaff.rows[0].s).toBe(false);
    });

    it("lets staff read questions through policy", async () => {
      const u = crypto.randomUUID();
      await admin.query("insert into auth.users (id) values ($1)", [u]);
      await admin.query("insert into staff_roles (user_id, role) values ($1, 'moderator')", [u]);
      const r = await asRole("authenticated", u, () => admin.query("select count(*)::int as n from questions"));
      expect(r.rows[0].n).toBeGreaterThan(0);
    });
  });
});

if (url) gameplaySuite("postgres", () => createPostgresRepositories(url));
