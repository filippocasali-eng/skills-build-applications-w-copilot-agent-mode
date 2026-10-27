import "server-only";
import { createMemoryRepositories } from "./memory";
import { createPostgresRepositories } from "./postgres";
import type { Repositories } from "./types";

export type { Repositories } from "./types";

const globalStore = globalThis as unknown as { __battlequizRepos?: Repositories };

/**
 * Returns the configured data store. With DATABASE_URL set, PostgreSQL is used;
 * otherwise a clearly labelled in-memory development store.
 */
export function getRepositories(): Repositories {
  if (!globalStore.__battlequizRepos) {
    const url = process.env.DATABASE_URL;
    if (!url && process.env.NODE_ENV === "production" && process.env.BATTLEQUIZ_ALLOW_MEMORY_STORE !== "true") {
      throw new Error("DATABASE_URL is required in production (set BATTLEQUIZ_ALLOW_MEMORY_STORE=true only for demos).");
    }
    globalStore.__battlequizRepos = url ? createPostgresRepositories(url) : createMemoryRepositories();
    if (!url) console.warn("[battlequiz] DATABASE_URL not set: using the in-memory LOCAL DEVELOPMENT store.");
  }
  return globalStore.__battlequizRepos;
}
