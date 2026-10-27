/**
 * Usage:
 *   npm run db:migrate            apply supabase/migrations to DATABASE_URL
 *   npm run db:seed               insert the bundled seed question bank
 *   npm run db:setup-local        plain PostgreSQL only: Supabase emulation + migrate + seed
 */
import { Client } from "pg";
import { loadSeedQuestions } from "../src/features/questions/bank";
import { applyLocalBootstrap, applyMigrations, seedQuestions } from "../src/lib/db/tools";

async function main() {
  const command = process.argv[2];
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error("DATABASE_URL is not set");
  const client = new Client({ connectionString: url });
  await client.connect();
  try {
    if (command === "setup-local") await applyLocalBootstrap(client);
    if (command === "migrate" || command === "setup-local") {
      const applied = await applyMigrations(client);
      console.log(applied.length ? `Applied: ${applied.join(", ")}` : "No pending migrations");
    }
    if (command === "seed" || command === "setup-local") {
      console.log(`Seeded ${await seedQuestions(client, loadSeedQuestions())} new questions`);
    }
    if (!["migrate", "seed", "setup-local"].includes(command)) throw new Error(`Unknown command: ${command}`);
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
