import { z } from "zod";
import { LOCALES, QUESTION_CATEGORIES } from "@/types/game";

export const LocaleSchema = z.enum(LOCALES);

export const CreateMatchSchema = z.object({
  locale: LocaleSchema.default("it"),
  category: z.enum([...QUESTION_CATEGORIES, "mixed"]).default("mixed"),
  mode: z.enum(["quick_play", "daily_challenge"]).default("quick_play"),
});

export const SubmitAnswerSchema = z.object({
  questionIndex: z.number().int().min(0).max(99),
  /** null reports that the timer expired on the client. */
  selectedIndex: z.number().int().min(0).max(3).nullable(),
});

export const MatchIdSchema = z.uuid();
