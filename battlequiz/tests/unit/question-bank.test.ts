import { describe, expect, it } from "vitest";
import { loadSeedQuestions } from "@/features/questions/bank";
import { QUICK_PLAY_DIFFICULTY_PLAN } from "@/features/questions/selection";
import { LocalizedQuestionSchema, QuestionSchema } from "@/lib/validation/question";
import { DIFFICULTIES, LOCALES, QUESTION_CATEGORIES } from "@/types/game";

const questions = loadSeedQuestions();

describe("seed question bank", () => {
  it("passes the strict question schema", () => {
    for (const q of questions) expect(() => QuestionSchema.parse(q), q.id).not.toThrow();
  });

  it("has unique ids and both locales for every translation key", () => {
    expect(new Set(questions.map((q) => q.id)).size).toBe(questions.length);
    const byKey = new Map<string, Set<string>>();
    for (const q of questions) byKey.set(q.translationKey, (byKey.get(q.translationKey) ?? new Set()).add(q.locale));
    for (const [key, locales] of byKey) expect([...locales].sort(), key).toEqual([...LOCALES].sort());
  });

  it("has no duplicate question texts within a locale", () => {
    for (const locale of LOCALES) {
      const texts = questions.filter((q) => q.locale === locale).map((q) => q.text.toLowerCase());
      expect(new Set(texts).size).toBe(texts.length);
    }
  });

  it("covers every category with enough questions for a full match", () => {
    for (const locale of LOCALES) {
      for (const category of QUESTION_CATEGORIES) {
        const n = questions.filter((q) => q.locale === locale && q.category === category).length;
        expect(n, `${locale}/${category}`).toBeGreaterThanOrEqual(QUICK_PLAY_DIFFICULTY_PLAN.length);
      }
    }
  });

  it("covers every difficulty level in every locale", () => {
    for (const locale of LOCALES) {
      for (const d of DIFFICULTIES) {
        expect(questions.some((q) => q.locale === locale && q.difficulty === d), `${locale}/${d}`).toBe(true);
      }
    }
  });

  it("keeps seed questions out of ranked play until a human signs them off", () => {
    expect(questions.every((q) => q.rankedEligible === false)).toBe(true);
  });
});

describe("LocalizedQuestionSchema quality checks", () => {
  const base = { text: "Qual è la capitale d'Italia?", options: ["Roma", "Milano", "Napoli", "Torino"], explanation: "Roma è la capitale." };
  it("accepts a valid question", () => {
    expect(LocalizedQuestionSchema.safeParse(base).success).toBe(true);
  });
  it("rejects duplicate options (case-insensitive)", () => {
    expect(LocalizedQuestionSchema.safeParse({ ...base, options: ["Roma", "roma", "Napoli", "Torino"] }).success).toBe(false);
  });
  it("rejects anything other than four options", () => {
    expect(LocalizedQuestionSchema.safeParse({ ...base, options: ["Roma", "Milano", "Napoli"] }).success).toBe(false);
  });
  it("rejects empty fields", () => {
    expect(LocalizedQuestionSchema.safeParse({ ...base, options: ["Roma", " ", "Napoli", "Torino"] }).success).toBe(false);
    expect(LocalizedQuestionSchema.safeParse({ ...base, explanation: "" }).success).toBe(false);
  });
});
