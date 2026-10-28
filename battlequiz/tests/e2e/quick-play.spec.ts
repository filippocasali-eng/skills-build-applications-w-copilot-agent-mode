import { expect, test, type Page } from "@playwright/test";

function collectErrors(page: Page) {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (msg) => msg.type() === "error" && errors.push(msg.text()));
  return errors;
}

/** Opens the app shell and skips first-launch onboarding. */
async function enterApp(page: Page, path = "/app") {
  await page.goto(path);
  await page.getByTestId("onboarding-skip").click();
  await expect(page.getByTestId("onboarding")).toHaveCount(0);
}

async function playFullMatch(page: Page, label = "Domanda") {
  for (let i = 1; i <= 10; i++) {
    await expect(page.getByTestId("question-counter")).toContainText(`${label} ${i}/10`, { timeout: 15_000 });
    const answers = page.locator('[data-testid^="answer-"]');
    await expect(answers).toHaveCount(4);
    await expect(answers.nth(i % 4)).toBeEnabled();
    await answers.nth(i % 4).click();
    await expect(page.getByTestId("feedback")).toBeVisible();
    await expect(page.locator('[data-state="correct"], [data-state="reveal"]')).toHaveCount(1);
  }
  await expect(page.getByTestId("final-score")).toBeAttached({ timeout: 15_000 });
}

test("landing page presents the game and opens the app", async ({ page }) => {
  const errors = collectErrors(page);
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1 })).toContainText("Pensa veloce");
  await expect(page.getByRole("link", { name: "Privacy" })).toBeVisible();
  await page.getByTestId("hero-play").click();
  await expect(page).toHaveURL(/\/app$/);
  await expect(page.getByTestId("onboarding")).toBeVisible();
  expect(errors).toEqual([]);
});

test("onboarding sets the nickname shown on home and profile", async ({ page }) => {
  await page.goto("/app");
  for (let i = 0; i < 3; i++) await page.getByTestId("onboarding-next").click();
  await page.getByTestId("onboarding-name").fill("Ada");
  await page.getByTestId("onboarding-next").click();
  await expect(page.getByTestId("home-name")).toHaveText("Ada");
  await page.getByTestId("tab-profile").click();
  await expect(page.getByTestId("profile-name")).toHaveText("Ada");
  // Onboarding is shown only once.
  await page.reload();
  await expect(page.getByTestId("home-name")).toHaveText("Ada");
  await expect(page.getByTestId("onboarding")).toHaveCount(0);
});

test("a guest completes a full 10-question match and progress is saved", async ({ page }) => {
  const errors = collectErrors(page);
  await enterApp(page);
  await page.getByTestId("home-quick-play").click();
  await playFullMatch(page);
  await expect(page.getByText("Risposte esatte").first()).toBeVisible();

  await page.getByRole("button", { name: "Rivedi le risposte" }).click();
  await expect(page.getByText("Risposta corretta:").first()).toBeVisible();

  // Replay goes straight into a new match.
  await page.getByTestId("play-again").click();
  await expect(page.getByTestId("question-counter")).toContainText("Domanda 1/10", { timeout: 15_000 });
  await page.getByRole("button", { name: "Esci dalla partita" }).click();
  await page.getByTestId("quit-confirm").click();

  await page.getByTestId("tab-profile").click();
  await expect(page.getByText("Partite").first()).toBeVisible();
  await expect(page.getByText("Partita rapida").first()).toBeVisible();
  expect(errors).toEqual([]);
});

test("category practice from the Play tab uses only that category", async ({ page }) => {
  await enterApp(page, "/play");
  await page.getByTestId("category-geography").click();
  await expect(page.getByTestId("question-counter")).toContainText("Domanda 1/10", { timeout: 15_000 });
  await expect(page.getByText("Geografia").first()).toBeVisible();
});

test("the daily challenge can be played once and is then marked completed", async ({ page }) => {
  await enterApp(page);
  await page.getByTestId("home-daily").click();
  await playFullMatch(page);
  await page.getByRole("button", { name: "Torna alla home" }).last().click();
  await expect(page.getByTestId("home-daily")).toBeDisabled();
  await expect(page.getByTestId("home-daily")).toContainText("Completata");
});

test("an unanswered question times out with zero points", async ({ page }) => {
  await enterApp(page);
  await page.getByTestId("home-quick-play").click();
  await expect(page.getByTestId("question-counter")).toContainText("Domanda 1/10", { timeout: 15_000 });
  await expect(page.getByTestId("feedback")).toContainText("Tempo scaduto", { timeout: 20_000 });
  await expect(page.getByTestId("question-counter")).toContainText("Domanda 2/10", { timeout: 15_000 });
});

test("the language can be switched to English", async ({ page }) => {
  await page.goto("/app");
  await page.getByRole("radio", { name: "EN" }).click();
  await page.getByTestId("onboarding-skip").click();
  await page.getByTestId("tab-play").click();
  await expect(page.getByRole("heading", { name: "Play" })).toBeVisible();
  await page.getByTestId("mode-quick").click();
  await expect(page.getByTestId("question-counter")).toContainText("Question 1/10", { timeout: 15_000 });
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

test("the daily challenge serves the same first question to everyone", async ({ playwright, baseURL }) => {
  const a = await playwright.request.newContext({ baseURL });
  const b = await playwright.request.newContext({ baseURL });
  const qa = await (await a.post("/api/matches", { data: { locale: "it", mode: "daily_challenge" } })).json();
  const qb = await (await b.post("/api/matches", { data: { locale: "it", mode: "daily_challenge" } })).json();
  expect(qa.matchId).not.toBe(qb.matchId);
  expect(qa.question).toEqual(qb.question);
});

test("cross-site match creation is rejected", async ({ request }) => {
  const res = await request.post("/api/matches", { data: {}, headers: { Origin: "https://evil.example" } });
  expect(res.status()).toBe(403);
});
