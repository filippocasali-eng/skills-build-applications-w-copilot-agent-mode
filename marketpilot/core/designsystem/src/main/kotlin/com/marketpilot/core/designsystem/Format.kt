package com.marketpilot.core.designsystem

import com.marketpilot.core.common.AppClock
import com.marketpilot.core.model.Freshness
import java.text.NumberFormat
import java.time.Instant
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Italian number/date formatting. All display times are converted from UTC to Europe/Rome. */
object Fmt {
    val IT: Locale = Locale.ITALY
    private val dateFmt = DateTimeFormatter.ofPattern("d MMM yyyy", IT)
    private val dateTimeFmt = DateTimeFormatter.ofPattern("d MMM yyyy, HH:mm", IT)
    private val timeFmt = DateTimeFormatter.ofPattern("HH:mm", IT)

    fun eur(x: Double?): String = x?.let { NumberFormat.getCurrencyInstance(IT).apply { currency = java.util.Currency.getInstance("EUR") }.format(it) } ?: "—"
    fun money(x: Double?, ccy: String): String = x?.let {
        NumberFormat.getCurrencyInstance(IT).apply { currency = java.util.Currency.getInstance(ccy) }.format(it)
    } ?: "—"
    fun num(x: Double?, decimals: Int = 2): String = x?.let { NumberFormat.getNumberInstance(IT).apply { minimumFractionDigits = decimals; maximumFractionDigits = decimals }.format(it) } ?: "—"
    fun pct(x: Double?, decimals: Int = 1, signed: Boolean = true): String = x?.let {
        (if (signed && it > 0) "+" else "") + NumberFormat.getNumberInstance(IT).apply { minimumFractionDigits = decimals; maximumFractionDigits = decimals }.format(it * 100) + "%"
    } ?: "—"
    fun compact(x: Double?): String = when {
        x == null -> "—"
        kotlin.math.abs(x) >= 1e12 -> num(x / 1e12, 2) + " T"
        kotlin.math.abs(x) >= 1e9 -> num(x / 1e9, 2) + " Mld"
        kotlin.math.abs(x) >= 1e6 -> num(x / 1e6, 1) + " Mln"
        kotlin.math.abs(x) >= 1e3 -> num(x / 1e3, 1) + " k"
        else -> num(x, 0)
    }
    fun date(d: LocalDate?): String = d?.format(dateFmt) ?: "—"
    /** Formats a stored ISO date ("2026-10-28") the Italian way; returns the input if it is not a date. */
    fun date(iso: String?): String = iso?.let { runCatching { LocalDate.parse(it).format(dateFmt) }.getOrDefault(it) } ?: "—"
    fun dateTime(i: Instant?): String = i?.atZone(AppClock.DISPLAY_ZONE)?.format(dateTimeFmt) ?: "—"
    fun time(i: Instant?): String = i?.atZone(AppClock.DISPLAY_ZONE)?.format(timeFmt) ?: "—"

    fun freshness(f: Freshness): String = when (f) {
        Freshness.LIVE -> "In tempo reale"
        Freshness.DELAYED -> "Ritardato"
        Freshness.END_OF_DAY -> "Chiusura ultima seduta"
        Freshness.STALE -> "Non aggiornato"
        Freshness.UNKNOWN -> "Freschezza sconosciuta"
    }
}
