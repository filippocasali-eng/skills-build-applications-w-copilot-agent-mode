"use client";

import { AlertTriangle, RotateCcw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useMessages } from "@/i18n";

export function ErrorPanel({ code, onRetry }: { code: string | null; onRetry: () => void }) {
  const { m } = useMessages();
  const message =
    code === "NETWORK" ? m.errors.network
    : code === "RATE_LIMITED" ? m.errors.rateLimited
    : code === "EXPIRED" ? m.errors.expired
    : code === "NOT_FOUND" ? m.errors.notFound
    : m.errors.generic;
  return (
    <div role="alert" className="card-glass mx-auto mt-10 max-w-md rounded-3xl p-8 text-center">
      <AlertTriangle className="mx-auto h-12 w-12 text-gold" aria-hidden="true" />
      <h2 className="mt-4 font-display text-2xl font-bold">{m.errors.title}</h2>
      <p className="mt-2 text-muted">{message}</p>
      <Button className="mt-6" onClick={onRetry}>
        <RotateCcw className="h-5 w-5" /> {m.errors.newGame}
      </Button>
    </div>
  );
}
