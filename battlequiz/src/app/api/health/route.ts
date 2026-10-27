import { connection } from "next/server";
import { json } from "@/lib/http";
import { getRepositories } from "@/lib/store";

/** Liveness + which data store is active ("memory" means local development mode). */
export async function GET() {
  await connection(); // always evaluated per request, never prerendered
  return json({ ok: true, store: getRepositories().kind });
}
