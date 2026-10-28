/** UTC day used as the daily challenge id, e.g. "2026-10-28". Shared by server and client. */
export function utcDay(now: number): string {
  return new Date(now).toISOString().slice(0, 10);
}
