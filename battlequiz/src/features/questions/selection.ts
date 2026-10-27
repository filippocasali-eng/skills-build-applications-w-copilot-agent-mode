import { shuffle, type Rng } from "@/lib/random";
import {
  DIFFICULTIES,
  type CategorySelection,
  type Difficulty,
  type MatchQuestion,
  type Question,
} from "@/types/game";

export const QUICK_PLAY_LENGTH = 10;

/** Progressive difficulty curve for a 10-question Quick Play match. */
export const QUICK_PLAY_DIFFICULTY_PLAN: readonly Difficulty[] = [
  "easy",
  "easy",
  "easy",
  "medium",
  "medium",
  "medium",
  "hard",
  "hard",
  "hard",
  "expert",
];

export class QuestionExhaustionError extends Error {
  constructor(
    public readonly needed: number,
    public readonly available: number,
  ) {
    super(`Not enough questions: needed ${needed}, available ${available}`);
    this.name = "QuestionExhaustionError";
  }
}

export interface SelectionOptions {
  pool: readonly Question[];
  category: CategorySelection;
  plan?: readonly Difficulty[];
  /** Question ids the player saw recently, most recent first. Used to avoid repeats. */
  recentlySeen?: readonly string[];
  /** In mixed mode, the maximum number of questions from a single category. */
  maxPerCategory?: number;
  rng: Rng;
}

/** Difficulties ordered by distance from the target, used when a tier runs dry. */
function fallbackOrder(target: Difficulty): Difficulty[] {
  const t = DIFFICULTIES.indexOf(target);
  return [...DIFFICULTIES].sort((a, b) => {
    const da = Math.abs(DIFFICULTIES.indexOf(a) - t);
    const db = Math.abs(DIFFICULTIES.indexOf(b) - t);
    return da - db || DIFFICULTIES.indexOf(a) - DIFFICULTIES.indexOf(b);
  });
}

/**
 * Picks questions for a match following the difficulty plan.
 * Priority: unseen questions at the target difficulty, then unseen at the nearest
 * difficulty, then the least recently seen questions. Mixed mode spreads
 * categories and avoids the same category twice in a row when possible.
 */
export function selectQuestions(opts: SelectionOptions): Question[] {
  const plan = opts.plan ?? QUICK_PLAY_DIFFICULTY_PLAN;
  const maxPerCategory = opts.maxPerCategory ?? 3;
  const mixed = opts.category === "mixed";
  const candidates = mixed ? opts.pool : opts.pool.filter((q) => q.category === opts.category);
  if (candidates.length < plan.length) throw new QuestionExhaustionError(plan.length, candidates.length);

  const seenRank = new Map<string, number>();
  (opts.recentlySeen ?? []).forEach((id, i) => {
    if (!seenRank.has(id)) seenRank.set(id, i);
  });
  // Unseen first (random order), then seen from least to most recent.
  const ordered = shuffle(candidates, opts.rng).sort((a, b) => {
    const ra = seenRank.has(a.id) ? 1 : 0;
    const rb = seenRank.has(b.id) ? 1 : 0;
    if (ra !== rb) return ra - rb;
    if (ra === 1) return (seenRank.get(b.id) ?? 0) - (seenRank.get(a.id) ?? 0);
    return 0;
  });

  const used = new Set<string>();
  const perCategory = new Map<string, number>();
  const picked: Question[] = [];

  for (const target of plan) {
    const last = picked[picked.length - 1];
    let choice: Question | undefined;
    const categoryOk = (q: Question, strict: boolean): boolean => {
      if (!mixed) return true;
      if ((perCategory.get(q.category) ?? 0) >= maxPerCategory) return false;
      return !strict || !last || last.category !== q.category;
    };
    // Relax constraints progressively: seen-ness, category balance, then difficulty.
    const passes: Array<(q: Question) => boolean> = [
      (q) => !seenRank.has(q.id) && categoryOk(q, true),
      (q) => !seenRank.has(q.id) && categoryOk(q, false),
      (q) => categoryOk(q, true),
      () => true,
    ];
    outer: for (const accept of passes) {
      for (const difficulty of fallbackOrder(target)) {
        choice = ordered.find((q) => !used.has(q.id) && q.difficulty === difficulty && accept(q));
        if (choice) break outer;
      }
    }
    if (!choice) throw new QuestionExhaustionError(plan.length, picked.length);
    used.add(choice.id);
    perCategory.set(choice.category, (perCategory.get(choice.category) ?? 0) + 1);
    picked.push(choice);
  }
  return picked;
}

/**
 * Builds the per-match answer order. Correct-answer display positions are drawn
 * from a balanced bag (each of A–D appears equally often, ±1) so players cannot
 * exploit a positional bias, then the distractors are shuffled around it.
 */
export function buildMatchQuestions(questions: readonly Question[], rng: Rng): MatchQuestion[] {
  const bag: number[] = [];
  while (bag.length < questions.length) bag.push(...shuffle([0, 1, 2, 3], rng));
  return questions.map((q, i) => {
    const correctDisplay = bag[i];
    const distractors = shuffle(
      [0, 1, 2, 3].filter((c) => c !== q.correctIndex),
      rng,
    );
    const order: number[] = [];
    for (let d = 0; d < 4; d++) order.push(d === correctDisplay ? q.correctIndex : distractors.shift()!);
    return {
      questionId: q.id,
      category: q.category,
      difficulty: q.difficulty,
      optionOrder: order as MatchQuestion["optionOrder"],
      correctDisplayIndex: correctDisplay,
    };
  });
}
