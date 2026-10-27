import { SeedFileSchema, type SeedFile } from "@/lib/validation/question";
import { LOCALES, type Question } from "@/types/game";
import art from "@/data/questions/art.json";
import food from "@/data/questions/food.json";
import general from "@/data/questions/general.json";
import geography from "@/data/questions/geography.json";
import history from "@/data/questions/history.json";
import logic from "@/data/questions/logic.json";
import moviesTv from "@/data/questions/movies_tv.json";
import music from "@/data/questions/music.json";
import nature from "@/data/questions/nature.json";
import popCulture from "@/data/questions/pop_culture.json";
import science from "@/data/questions/science.json";
import sports from "@/data/questions/sports.json";
import technology from "@/data/questions/technology.json";
import videoGames from "@/data/questions/video_games.json";

/**
 * Seed question bank bundled with the app. It is the question source in local
 * development mode and the input of `npm run db:seed` for PostgreSQL.
 */
export const SEED_FILES: readonly unknown[] = [
  general,
  history,
  geography,
  science,
  technology,
  moviesTv,
  music,
  sports,
  nature,
  food,
  art,
  logic,
  videoGames,
  popCulture,
];

/** Seed questions are human-curated but not yet signed off for ranked play. */
const SEED_CREATED_AT = "2026-10-27T00:00:00.000Z";

export function expandSeedFile(file: SeedFile): Question[] {
  const out: Question[] = [];
  for (const q of file.questions) {
    for (const locale of LOCALES) {
      const loc = q[locale];
      out.push({
        id: `${q.key}-${locale}`,
        translationKey: q.key,
        locale,
        category: file.category,
        difficulty: q.difficulty,
        text: loc.text,
        options: loc.options as Question["options"],
        correctIndex: file.correctIndex,
        explanation: loc.explanation,
        source: q.source,
        reviewStatus: "approved",
        rankedEligible: false,
        version: 1,
        createdAt: SEED_CREATED_AT,
      });
    }
  }
  return out;
}

let cache: Question[] | null = null;

/** Parses and validates every seed file. Throws on the first invalid file. */
export function loadSeedQuestions(): Question[] {
  if (cache) return cache;
  const all: Question[] = [];
  const keys = new Set<string>();
  for (const raw of SEED_FILES) {
    const file = SeedFileSchema.parse(raw);
    for (const q of file.questions) {
      if (keys.has(q.key)) throw new Error(`Duplicate seed question key ${q.key}`);
      keys.add(q.key);
    }
    all.push(...expandSeedFile(file));
  }
  cache = all;
  return all;
}
