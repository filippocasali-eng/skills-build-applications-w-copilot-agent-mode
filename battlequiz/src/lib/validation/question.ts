import { z } from "zod";
import { DIFFICULTIES, LOCALES, QUESTION_CATEGORIES, REVIEW_STATUSES } from "@/types/game";

const trimmed = (min: number, max: number) => z.string().trim().min(min).max(max);

/** One localized version of a question: text, four options and an explanation. */
export const LocalizedQuestionSchema = z
  .object({
    text: trimmed(8, 300),
    options: z.array(trimmed(1, 120)).length(4),
    explanation: trimmed(8, 400),
  })
  .superRefine((q, ctx) => {
    const normalized = q.options.map((o) => o.toLocaleLowerCase().replace(/\s+/g, " "));
    if (new Set(normalized).size !== normalized.length) {
      ctx.addIssue({ code: "custom", message: "Answer options must be unique", path: ["options"] });
    }
    if (normalized.includes(q.text.toLocaleLowerCase().replace(/\s+/g, " "))) {
      ctx.addIssue({ code: "custom", message: "An option repeats the question text", path: ["options"] });
    }
  });

export const QuestionSourceSchema = z.object({
  kind: z.enum(["editorial", "seed_ai_assisted", "ai_generated"]),
  reference: trimmed(3, 300),
});

/** Seed file format: options[correctIndex] is correct in every locale. */
export const SeedFileSchema = z.object({
  category: z.enum(QUESTION_CATEGORIES),
  correctIndex: z.literal(0),
  questions: z
    .array(
      z.object({
        key: z.string().regex(/^[a-z]{3}-\d{3}$/),
        difficulty: z.enum(DIFFICULTIES),
        source: QuestionSourceSchema,
        it: LocalizedQuestionSchema,
        en: LocalizedQuestionSchema,
      }),
    )
    .min(1),
});
export type SeedFile = z.infer<typeof SeedFileSchema>;

/** Fully expanded single-locale question, as stored in the database. */
export const QuestionSchema = z.object({
  id: z.string().min(1),
  translationKey: z.string().min(1),
  locale: z.enum(LOCALES),
  category: z.enum(QUESTION_CATEGORIES),
  difficulty: z.enum(DIFFICULTIES),
  text: trimmed(8, 300),
  options: z.tuple([trimmed(1, 120), trimmed(1, 120), trimmed(1, 120), trimmed(1, 120)]),
  correctIndex: z.union([z.literal(0), z.literal(1), z.literal(2), z.literal(3)]),
  explanation: trimmed(8, 400),
  source: QuestionSourceSchema,
  reviewStatus: z.enum(REVIEW_STATUSES),
  rankedEligible: z.boolean(),
  version: z.number().int().positive(),
  createdAt: z.string(),
});
