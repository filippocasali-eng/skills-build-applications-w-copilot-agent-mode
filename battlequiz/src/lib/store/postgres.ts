import { Pool, type PoolClient } from "pg";
import {
  QUESTION_CATEGORIES,
  type AnswerRecord,
  type MatchQuestion,
  type Question,
  type QuestionCategory,
} from "@/types/game";
import type { Repositories } from "./types";

/**
 * PostgreSQL adapter (works with Supabase's Postgres connection string).
 * Server-only: the connection uses a privileged role and bypasses RLS, so it
 * must never be reachable from the browser.
 */

interface QuestionRow {
  id: string;
  translation_key: string;
  locale: Question["locale"];
  category_id: QuestionCategory;
  difficulty: Question["difficulty"];
  text: string;
  options: string[];
  correct_index: number;
  explanation: string;
  source_kind: Question["source"]["kind"];
  source_reference: string;
  review_status: Question["reviewStatus"];
  ranked_eligible: boolean;
  version: number;
  created_at: Date;
}

const QUESTION_COLUMNS =
  "id, translation_key, locale, category_id, difficulty, text, options, correct_index, explanation, source_kind, source_reference, review_status, ranked_eligible, version, created_at";

function toQuestion(r: QuestionRow): Question {
  return {
    id: r.id,
    translationKey: r.translation_key,
    locale: r.locale,
    category: r.category_id,
    difficulty: r.difficulty,
    text: r.text,
    options: r.options as Question["options"],
    correctIndex: r.correct_index as Question["correctIndex"],
    explanation: r.explanation,
    source: { kind: r.source_kind, reference: r.source_reference },
    reviewStatus: r.review_status,
    rankedEligible: r.ranked_eligible,
    version: r.version,
    createdAt: r.created_at.toISOString(),
  };
}

const ms = (d: Date | null): number | null => (d ? d.getTime() : null);
const ts = (n: number | null): Date | null => (n === null ? null : new Date(n));

async function inTransaction<T>(pool: Pool, fn: (c: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query("begin");
    const result = await fn(client);
    await client.query("commit");
    return result;
  } catch (err) {
    await client.query("rollback").catch(() => undefined);
    throw err;
  } finally {
    client.release();
  }
}

async function insertAnswers(c: PoolClient, matchId: string, playerKey: string, answers: readonly AnswerRecord[]) {
  for (const a of answers) {
    await c.query(
      `insert into player_answers (match_id, player_key, question_index, selected_index, correct, timed_out,
         elapsed_ms, points, base_points, speed_bonus, multiplier, streak_after, answered_at)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
      [matchId, playerKey, a.questionIndex, a.selectedIndex, a.correct, a.timedOut, a.elapsedMs, a.points,
        a.basePoints, a.speedBonus, a.multiplier, a.streakAfter, new Date(a.answeredAt)],
    );
  }
}

export function createPostgresRepositories(connectionString: string): Repositories {
  const pool = new Pool({ connectionString, max: Number(process.env.DATABASE_POOL_MAX ?? 5) });

  return {
    kind: "postgres",
    questions: {
      async listPlayable(locale) {
        const { rows } = await pool.query<QuestionRow>(
          `select ${QUESTION_COLUMNS} from questions where locale = $1 and review_status = 'approved'`,
          [locale],
        );
        return rows.map(toQuestion);
      },
      async getByIds(ids) {
        if (ids.length === 0) return new Map();
        const { rows } = await pool.query<QuestionRow>(`select ${QUESTION_COLUMNS} from questions where id = any($1)`, [
          ids,
        ]);
        return new Map(rows.map((r) => [r.id, toQuestion(r)]));
      },
      async countByCategory(locale) {
        const { rows } = await pool.query<{ category_id: QuestionCategory; n: string }>(
          `select category_id, count(*) as n from questions where locale = $1 and review_status = 'approved' group by category_id`,
          [locale],
        );
        const counts = Object.fromEntries(QUESTION_CATEGORIES.map((c) => [c, 0])) as Record<QuestionCategory, number>;
        for (const r of rows) counts[r.category_id] = Number(r.n);
        return counts;
      },
    },

    matches: {
      async create(s) {
        await inTransaction(pool, async (c) => {
          await c.query(
            `insert into matches (id, mode, status, locale, category, ruleset_version, created_by, created_at, completed_at, version)
             values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
            [s.id, s.mode, s.status, s.locale, s.category, s.rulesetVersion, s.playerKey, new Date(s.createdAt),
              ts(s.completedAt), s.version],
          );
          const userId = s.playerKey.startsWith("user:") ? s.playerKey.slice(5) : null;
          await c.query(
            `insert into match_players (match_id, player_key, user_id, current_index, current_issued_at, score, streak, best_streak)
             values ($1,$2,$3,$4,$5,$6,$7,$8)`,
            [s.id, s.playerKey, userId, s.currentIndex, ts(s.currentIssuedAt), s.score, s.streak, s.bestStreak],
          );
          for (const [i, q] of s.questions.entries()) {
            await c.query(
              `insert into match_questions (match_id, position, question_id, category, difficulty, option_order, correct_display_index)
               values ($1,$2,$3,$4,$5,$6,$7)`,
              [s.id, i, q.questionId, q.category, q.difficulty, q.optionOrder, q.correctDisplayIndex],
            );
          }
          await insertAnswers(c, s.id, s.playerKey, s.answers);
        });
      },

      async get(id) {
        const m = await pool.query(
          `select m.*, p.player_key, p.current_index, p.current_issued_at, p.score, p.streak, p.best_streak
             from matches m join match_players p on p.match_id = m.id
            where m.id = $1 and m.mode = 'quick_play'`,
          [id],
        );
        if (m.rowCount === 0) return null;
        const row = m.rows[0];
        const [qs, as] = await Promise.all([
          pool.query(`select * from match_questions where match_id = $1 order by position`, [id]),
          pool.query(`select * from player_answers where match_id = $1 and player_key = $2 order by question_index`, [
            id,
            row.player_key,
          ]),
        ]);
        const questions: MatchQuestion[] = qs.rows.map((q) => ({
          questionId: q.question_id,
          category: q.category,
          difficulty: q.difficulty,
          optionOrder: q.option_order as MatchQuestion["optionOrder"],
          correctDisplayIndex: q.correct_display_index,
        }));
        const answers: AnswerRecord[] = as.rows.map((a) => ({
          questionIndex: a.question_index,
          selectedIndex: a.selected_index,
          correct: a.correct,
          timedOut: a.timed_out,
          elapsedMs: a.elapsed_ms,
          points: a.points,
          basePoints: a.base_points,
          speedBonus: a.speed_bonus,
          multiplier: Number(a.multiplier),
          streakAfter: a.streak_after,
          answeredAt: a.answered_at.getTime(),
        }));
        return {
          id: row.id,
          mode: row.mode,
          status: row.status,
          playerKey: row.player_key,
          locale: row.locale,
          category: row.category,
          rulesetVersion: row.ruleset_version,
          questions,
          currentIndex: row.current_index,
          currentIssuedAt: ms(row.current_issued_at),
          answers,
          score: row.score,
          streak: row.streak,
          bestStreak: row.best_streak,
          createdAt: row.created_at.getTime(),
          completedAt: ms(row.completed_at),
          version: row.version,
        };
      },

      async save(next, expectedVersion) {
        return inTransaction(pool, async (c) => {
          // Row lock + version check: concurrent writers serialize here and the loser gets rowCount 0.
          const upd = await c.query(
            `update matches set status = $3, completed_at = $4, version = version + 1
              where id = $1 and version = $2`,
            [next.id, expectedVersion, next.status, ts(next.completedAt)],
          );
          if (upd.rowCount === 0) return false;
          await c.query(
            `update match_players set current_index = $3, current_issued_at = $4, score = $5, streak = $6,
                    best_streak = $7, finished_at = $8
              where match_id = $1 and player_key = $2`,
            [next.id, next.playerKey, next.currentIndex, ts(next.currentIssuedAt), next.score, next.streak,
              next.bestStreak, next.status === "COMPLETED" ? ts(next.completedAt) : null],
          );
          const { rows } = await c.query<{ n: number }>(
            `select count(*)::int as n from player_answers where match_id = $1 and player_key = $2`,
            [next.id, next.playerKey],
          );
          // The primary key on player_answers rejects any duplicate question_index.
          await insertAnswers(c, next.id, next.playerKey, next.answers.slice(rows[0].n));
          return true;
        });
      },
    },

    history: {
      async recent(playerKey, limit) {
        const { rows } = await pool.query<{ question_id: string }>(
          `select question_id from player_question_history where player_key = $1 order by seen_at desc limit $2`,
          [playerKey, limit],
        );
        return rows.map((r) => r.question_id);
      },
      async record(playerKey, ids, at) {
        if (ids.length === 0) return;
        await pool.query(
          `insert into player_question_history (player_key, question_id, seen_at)
           select $1, q.id, to_timestamp(($3::bigint + q.ord) / 1000.0)
             from unnest($2::text[]) with ordinality as q(id, ord)
           on conflict (player_key, question_id)
           do update set seen_at = excluded.seen_at, times_seen = player_question_history.times_seen + 1`,
          [playerKey, ids, at],
        );
      },
    },

    audit: {
      async log(e) {
        await pool.query(`insert into audit_events (actor_key, action, subject, metadata) values ($1,$2,$3,$4)`, [
          e.actorKey,
          e.action,
          e.subject ?? null,
          JSON.stringify(e.metadata ?? {}),
        ]);
      },
    },
  };
}
