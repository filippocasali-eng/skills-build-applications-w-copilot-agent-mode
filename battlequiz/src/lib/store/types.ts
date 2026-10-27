import type { Locale, MatchState, Question, QuestionCategory } from "@/types/game";

export interface QuestionRepository {
  /** Approved questions that may be served in casual play for a locale. */
  listPlayable(locale: Locale): Promise<Question[]>;
  getByIds(ids: readonly string[]): Promise<Map<string, Question>>;
  countByCategory(locale: Locale): Promise<Record<QuestionCategory, number>>;
}

export interface MatchRepository {
  create(state: MatchState): Promise<void>;
  get(id: string): Promise<MatchState | null>;
  /**
   * Persists `next` only if the stored version still equals `expectedVersion`
   * (optimistic concurrency). Returns false on a conflicting concurrent write.
   * On success the stored version becomes `expectedVersion + 1`.
   */
  save(next: MatchState, expectedVersion: number): Promise<boolean>;
}

export interface HistoryRepository {
  /** Question ids the player has seen, most recent first. */
  recent(playerKey: string, limit: number): Promise<string[]>;
  record(playerKey: string, questionIds: readonly string[], at: number): Promise<void>;
}

export interface AuditRepository {
  log(event: { actorKey: string | null; action: string; subject?: string; metadata?: Record<string, unknown> }): Promise<void>;
}

export interface Repositories {
  kind: "memory" | "postgres";
  questions: QuestionRepository;
  matches: MatchRepository;
  history: HistoryRepository;
  audit: AuditRepository;
}
