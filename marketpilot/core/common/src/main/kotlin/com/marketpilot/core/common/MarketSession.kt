package com.marketpilot.core.common

import com.marketpilot.core.model.Freshness
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZonedDateTime

enum class SessionPhase(val label: String) {
    PRE_MARKET("Pre-mercato"),
    OPEN("Mercato aperto"),
    AFTER_HOURS("After-hours"),
    CLOSED("Mercato chiuso"),
    WEEKEND("Weekend"),
    HOLIDAY("Festività di borsa"),
}

data class SessionStatus(
    val phase: SessionPhase,
    val exchange: String,
    /** Exchange-local date of the session that is open now, or of the last completed one. */
    val lastCompletedSession: LocalDate,
    val nextOpen: ZonedDateTime,
    val localNow: ZonedDateTime,
)

object MarketSessions {
    private val PRE_START = LocalTime.of(4, 0)
    private val AFTER_END = LocalTime.of(20, 0)

    fun status(calendar: TradingCalendar, now: Instant): SessionStatus {
        val local = now.atZone(calendar.zone)
        val date = local.toLocalDate()
        val time = local.toLocalTime()
        val tradingToday = calendar.isTradingDay(date)
        val close = calendar.closeTime(date)
        val phase = when {
            !tradingToday && (date.dayOfWeek.value >= 6) -> SessionPhase.WEEKEND
            !tradingToday -> SessionPhase.HOLIDAY
            time < calendar.regularOpen && calendar.exchange == "NYSE" && time >= PRE_START -> SessionPhase.PRE_MARKET
            time < calendar.regularOpen -> SessionPhase.CLOSED
            time < close -> SessionPhase.OPEN
            calendar.exchange == "NYSE" && time < AFTER_END -> SessionPhase.AFTER_HOURS
            else -> SessionPhase.CLOSED
        }
        val lastCompleted = lastCompletedSession(calendar, now)
        val nextOpenDate = if (tradingToday && time < calendar.regularOpen) date else calendar.nextTradingDay(date)
        val nextOpen = ZonedDateTime.of(nextOpenDate, calendar.regularOpen, calendar.zone)
        return SessionStatus(phase, calendar.exchange, lastCompleted, nextOpen, local)
    }

    /**
     * Latest session whose daily bar is final at [now]. A bar for today is considered final only
     * after the close plus [settle] (data vendors publish final daily bars with some delay).
     */
    fun lastCompletedSession(calendar: TradingCalendar, now: Instant, settle: Duration = Duration.ofMinutes(30)): LocalDate {
        val local = now.atZone(calendar.zone)
        val date = local.toLocalDate()
        if (calendar.isTradingDay(date)) {
            val closeAt = ZonedDateTime.of(date, calendar.closeTime(date), calendar.zone).plus(settle)
            if (!local.isBefore(closeAt)) return date
        }
        return calendar.previousTradingDay(date)
    }

    /**
     * Classifies how fresh an observation is. Daily bars dated on the last completed session are
     * END_OF_DAY; anything older is STALE. Intraday observations during an open session are LIVE
     * within 2 minutes and DELAYED otherwise.
     */
    fun classify(calendar: TradingCalendar, observedAt: Instant?, now: Instant): Freshness {
        if (observedAt == null) return Freshness.UNKNOWN
        val status = status(calendar, now)
        val obsDate = observedAt.atZone(calendar.zone).toLocalDate()
        if (status.phase == SessionPhase.OPEN && obsDate == status.localNow.toLocalDate()) {
            val age = Duration.between(observedAt, now)
            return if (age <= Duration.ofMinutes(2)) Freshness.LIVE else Freshness.DELAYED
        }
        val reference = status.lastCompletedSession
        return when {
            !obsDate.isBefore(reference) -> Freshness.END_OF_DAY
            else -> Freshness.STALE
        }
    }

    /** Freshness for a daily bar dated [barDate]. */
    fun classifyBarDate(calendar: TradingCalendar, barDate: LocalDate?, now: Instant): Freshness {
        if (barDate == null) return Freshness.UNKNOWN
        val reference = lastCompletedSession(calendar, now)
        val today = now.atZone(calendar.zone).toLocalDate()
        return when {
            barDate == today && calendar.isTradingDay(today) && barDate.isAfter(reference) -> Freshness.DELAYED
            !barDate.isBefore(reference) -> Freshness.END_OF_DAY
            else -> Freshness.STALE
        }
    }
}
