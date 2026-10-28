// @vitest-environment jsdom
import { describe, expect, it } from "vitest";
import { ApiError } from "@/features/gameplay/client-api-error";
import { localGameApi } from "@/features/gameplay/local-api";

describe("offline (on-device) game API", () => {
  it("plays a full match without a server and remembers seen questions", async () => {
    const { categories } = await localGameApi.categories("it");
    expect(categories).toContain("geography");

    const { matchId, question } = await localGameApi.start("it", "mixed");
    expect(question).not.toHaveProperty("correctIndex");
    for (let i = 0; i < 10; i++) {
      const snap = await localGameApi.current(matchId);
      expect(snap.question?.index).toBe(i);
      const { completed } = await localGameApi.answer(matchId, i, i % 4);
      expect(completed).toBe(i === 9);
    }
    const results = await localGameApi.results(matchId);
    expect(results.review).toHaveLength(10);
    expect(JSON.parse(localStorage.getItem("bq-offline-history")!)).toHaveLength(10);
  });

  it("maps engine errors to ApiError codes", async () => {
    const { matchId } = await localGameApi.start("en", "science");
    await expect(localGameApi.results(matchId)).rejects.toMatchObject({ code: "NOT_COMPLETED" });
    await expect(localGameApi.answer(matchId, 5, 0)).rejects.toBeInstanceOf(ApiError);
  });
});
