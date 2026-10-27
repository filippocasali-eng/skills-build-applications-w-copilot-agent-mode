"use client";

import { useSettings } from "@/stores/settings";
import type { Locale } from "@/types/game";
import { en } from "./messages/en";
import { it } from "./messages/it";

export type Messages = typeof it;

export const MESSAGES: Record<Locale, Messages> = { it, en };

/** Replaces `{name}` placeholders. */
export function fmt(template: string, vars: Record<string, string | number>): string {
  return template.replace(/\{(\w+)\}/g, (m, k: string) => (k in vars ? String(vars[k]) : m));
}

export function useMessages(): { m: Messages; locale: Locale } {
  const locale = useSettings((s) => s.locale);
  return { m: MESSAGES[locale], locale };
}
