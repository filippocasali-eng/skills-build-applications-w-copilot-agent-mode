"use client";

import { ChevronRight, Cloud, FileText, Info, Languages, RotateCcw, Smartphone, Sparkles, Vibrate, Volume2, type LucideIcon } from "lucide-react";
import Link from "next/link";
import { useState, type ReactNode } from "react";
import { OFFLINE_MODE } from "@/features/gameplay/client-api";
import { useMessages } from "@/i18n";
import { haptic } from "@/lib/native";
import { cn } from "@/lib/utils";
import { useNav } from "@/stores/nav";
import { AVATAR_COLORS, usePlayer } from "@/stores/player";
import { useSettings, type MotionPreference } from "@/stores/settings";
import type { Locale } from "@/types/game";
import { Avatar, Pressable, ScreenHeader, Segmented, Sheet, Switch } from "./primitives";

export const APP_VERSION = "0.2.0";

function Group({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="mt-6">
      <h2 className="mb-2 px-4 text-xs font-bold uppercase tracking-widest text-muted">{title}</h2>
      <div className="divide-y divide-white/5 overflow-hidden rounded-3xl bg-surface ring-1 ring-white/10">{children}</div>
    </section>
  );
}

function Row({ icon: Icon, label, children, color = "#a78bfa" }: { icon: LucideIcon; label: string; children?: ReactNode; color?: string }) {
  return (
    <div className="flex min-h-14 items-center gap-3 px-4 py-2.5">
      <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl" style={{ background: `${color}22`, color }}>
        <Icon className="h-[18px] w-[18px]" />
      </span>
      <span className="flex-1 text-[15px] font-semibold">{label}</span>
      {children}
    </div>
  );
}

export function SettingsScreen() {
  const { m, locale } = useMessages();
  const pop = useNav((s) => s.pop);
  const s = useSettings();
  const { nickname, avatarColor, setProfile, resetProgress } = usePlayer();
  const [confirmReset, setConfirmReset] = useState(false);
  const t = m.app.settingsScreen;

  return (
    <div className="pb-10">
      <ScreenHeader title={m.app.settings} onBack={pop} />
      <div className="px-4">
        <Group title={t.profile}>
          <div className="flex items-center gap-4 p-4">
            <Avatar name={nickname || m.app.defaultName} color={avatarColor} size={56} />
            <label className="flex-1">
              <span className="text-xs font-semibold text-muted">{t.nickname}</span>
              <input
                value={nickname}
                maxLength={20}
                placeholder={m.app.defaultName}
                onChange={(e) => setProfile({ nickname: e.target.value })}
                className="mt-1 w-full rounded-xl bg-white/5 px-3 py-2.5 font-semibold outline-none ring-1 ring-white/10 focus:ring-primary"
                data-testid="settings-nickname"
              />
            </label>
          </div>
          <div className="px-4 pb-4">
            <p className="mb-2 text-xs font-semibold text-muted">{t.color}</p>
            <div className="flex flex-wrap gap-2.5" role="radiogroup" aria-label={t.color}>
              {AVATAR_COLORS.map((c) => (
                <button
                  key={c}
                  type="button"
                  role="radio"
                  aria-checked={c === avatarColor}
                  aria-label={c}
                  onClick={() => {
                    void haptic("tap");
                    setProfile({ avatarColor: c });
                  }}
                  className={cn("h-9 w-9 rounded-full transition-transform", c === avatarColor && "scale-110 ring-2 ring-white ring-offset-2 ring-offset-surface")}
                  style={{ background: c }}
                />
              ))}
            </div>
          </div>
        </Group>

        <Group title={t.general}>
          <Row icon={Languages} label={t.language} color="#06b6d4">
            <Segmented<Locale> label={t.language} value={locale} onChange={s.setLocale} options={[{ value: "it", label: "IT" }, { value: "en", label: "EN" }]} />
          </Row>
          <Row icon={Volume2} label={t.sound} color="#22c55e">
            <Switch checked={s.soundOn} onChange={s.toggleSound} label={t.sound} />
          </Row>
          <Row icon={Vibrate} label={t.haptics} color="#f59e0b">
            <Switch checked={s.hapticsOn} onChange={s.toggleHaptics} label={t.haptics} />
          </Row>
          <Row icon={Sparkles} label={t.motion} color="#ec4899">
            <Segmented<MotionPreference>
              label={t.motion}
              value={s.motion}
              onChange={s.setMotion}
              options={[{ value: "system", label: t.motionSystem }, { value: "reduce", label: t.motionReduce }, { value: "full", label: t.motionFull }]}
            />
          </Row>
        </Group>

        <Group title={t.account}>
          <Row icon={Cloud} label={t.accountSoon} color="#3b82f6">
            <span className="rounded-full bg-white/5 px-2.5 py-1 text-[11px] font-bold uppercase text-muted">{m.app.soon}</span>
          </Row>
        </Group>

        <Group title={t.data}>
          <Pressable haptics={false} onClick={() => setConfirmReset(true)} className="w-full">
            <Row icon={RotateCcw} label={t.reset} color="#ef4444">
              <ChevronRight className="h-5 w-5 text-muted" />
            </Row>
          </Pressable>
        </Group>

        <Group title={t.info}>
          <Row icon={Info} label={t.version} color="#94a3b8">
            <span className="text-sm text-muted">{APP_VERSION}</span>
          </Row>
          {OFFLINE_MODE && (
            <Row icon={Smartphone} label={t.offline} color="#94a3b8" />
          )}
          <Link href="/privacy" className="block">
            <Row icon={FileText} label={t.legal} color="#94a3b8">
              <ChevronRight className="h-5 w-5 text-muted" />
            </Row>
          </Link>
        </Group>
      </div>

      <Sheet open={confirmReset} onClose={() => setConfirmReset(false)} label={t.resetTitle}>
        <h2 className="font-display text-xl font-extrabold">{t.resetTitle}</h2>
        <p className="mt-2 text-sm text-muted">{t.resetText}</p>
        <div className="mt-6 grid grid-cols-2 gap-3 pb-4">
          <Pressable onClick={() => setConfirmReset(false)} className="rounded-2xl bg-white/10 py-3.5 text-center font-bold">
            {t.cancel}
          </Pressable>
          <Pressable
            haptics={false}
            onClick={() => {
              void haptic("warning");
              resetProgress();
              setConfirmReset(false);
            }}
            className="rounded-2xl bg-error py-3.5 text-center font-bold text-white"
          >
            {t.resetConfirm}
          </Pressable>
        </div>
      </Sheet>
    </div>
  );
}
