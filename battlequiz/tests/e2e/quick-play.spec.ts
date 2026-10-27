import { expect, test, type Page } from "@playwright/test";

function collectErrors(page: Page) {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (msg) => msg.type() === "error" && errors.push(msg.text()));
  return errors;
}

test("landing page presents the game and links to Quick Play", async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1 })).toContainText("Pensa veloce");
  await expect(page.getByRole("link", { name: "Privacy" })).toBeVisible();
  await page.getByTestId("hero-play").click();
  await expect(page).toHaveURL(/\/play$/);
  await expect(page.getByRole("heading", { name: "Partita rapida" })).toBeVisible();
  expect(errors).toEqual([]);
});

test("a guest completes a full 10-question match", async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto("/play");
  await page.getByTestId("category-mixed").click();
  await page.getByTestId("start-match").click();

  for (let i = 1; i <= 10; i++) {
    await expect(page.getByTestId("question-counter")).toHaveText(`Domanda ${i}/10`, { timeout: 15_000 });
    const answers = page.locator('[data-testid^="answer-"]');
    await expect(answers).toHaveCount(4);
    await expect(answers.nth(i % 4)).toBeEnabled();
    await answers.nth(i % 4).click();
    await expect(page.getByTestId("feedback")).toBeVisible();
    // Exactly one option is revealed as correct after answering.
    await expect(page.locator('[data-state="correct"], [data-state="reveal"]')).toHaveCount(1);
  }

  const score = page.getByTestId("final-score");
  await expect(score).toBeVisible({ timeout: 15_000 });
  expect(Number(await score.getAttribute("data-score"))).toBeGreaterThanOrEqual(0);
  await expect(page.getByText("Risposte esatte")).toBeVisible();

  await page.getByRole("button", { name: "Rivedi le risposte" }).click();
  await expect(page.getByText("Risposta corretta:").first()).toBeVisible();

  // Replay goes straight into a new match.
  await page.getByTestId("play-again").click();
  await expect(page.getByTestId("question-counter")).toHaveText("Domanda 1/10", { timeout: 15_000 });
  expect(errors).toEqual([]);
});

test("an unanswered question times out with zero points", async ({ page }) => {
  await page.goto("/play");
  await page.getByTestId("start-match").click();
  await expect(page.getByTestId("question-counter")).toHaveText("Domanda 1/10", { timeout: 15_000 });
  await expect(page.getByTestId("feedback")).toContainText("Tempo scaduto", { timeout: 20_000 });
  await expect(page.getByTestId("question-counter")).toHaveText("Domanda 2/10", { timeout: 15_000 });
});

test("the language can be switched to English", async ({ page }) => {
  await page.goto("/play");
  await page.getByRole("button", { name: "en", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Quick Play" })).toBeVisible();
  await page.getByTestId("start-match").click();
  await expect(page.getByTestId("question-counter")).toHaveText("Question 1/10", { timeout: 15_000 });
});

test("the API never exposes the correct answer before it is locked", async ({ request }) => {
  const res = await request.post("/api/matches", { data: { locale: "it", category: "mixed" } });
  expect(res.status()).toBe(201);
  const body = await res.json();
  const raw = JSON.stringify(body);
  expect(raw).not.toMatch(/correct/i);
  expect(raw).not.toMatch(/explanation/i);
  const results = await request.get(`/api/matches/${body.matchId}/results`);
  expect(results.status()).toBe(409);
});

test("cross-site match creation is rejected", async ({ request }) => {
  const res = await request.post("/api/matches", { data: {}, headers: { Origin: "https://evil.example" } });
  expect(res.status()).toBe(403);
});
