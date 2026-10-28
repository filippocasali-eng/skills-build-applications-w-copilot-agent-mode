"use client";

import { useMessages } from "@/i18n";
import { useNav } from "@/stores/nav";
import { usePlayer } from "@/stores/player";
import { MatchRow } from "./MatchRow";
import { ScreenHeader, timeAgo } from "./primitives";
import { useNow } from "./shared";

export function HistoryScreen() {
  const { m } = useMessages();
  const pop = useNav((s) => s.pop);
  const history = usePlayer((s) => s.progress.history);
  const now = useNow();
  return (
    <div className="pb-10">
      <ScreenHeader title={m.app.history.title} onBack={pop} />
      <div className="space-y-2 px-4 pt-2">
        {history.length === 0 ? (
          <p className="rounded-3xl bg-white/5 p-5 text-center text-sm text-muted">{m.app.noMatches}</p>
        ) : (
          history.map((h) => <MatchRow key={h.id} match={h} when={timeAgo(h.at, now, m.app.ago)} />)
        )}
      </div>
    </div>
  );
}
