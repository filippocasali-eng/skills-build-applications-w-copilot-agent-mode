import Link from "next/link";
import { Logo } from "@/components/layout/Logo";

export default function NotFound() {
  return (
    <main className="grid min-h-dvh place-items-center px-4 text-center">
      <div>
        <Logo size="lg" />
        <h1 className="mt-8 font-display text-4xl font-extrabold">404</h1>
        <p className="mt-2 text-muted">Pagina non trovata · Page not found</p>
        <Link href="/" className="mt-6 inline-block rounded-2xl bg-primary px-5 py-3 font-semibold text-white">
          Home
        </Link>
      </div>
    </main>
  );
}
