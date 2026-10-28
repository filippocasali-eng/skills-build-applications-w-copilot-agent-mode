package com.marketpilot.core.common

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalTime
import java.time.Month
import java.time.ZoneId
import java.time.temporal.TemporalAdjusters

/**
 * Rule-based exchange calendar. Holiday rules are deterministic; exceptional closures
 * (e.g. national days of mourning) are not predictable and are listed in [extraClosures].
 */
interface TradingCalendar {
    val exchange: String
    val zone: ZoneId
    val regularOpen: LocalTime
    val regularClose: LocalTime
    fun isHoliday(date: LocalDate): Boolean
    fun earlyClose(date: LocalDate): LocalTime? = null

    fun isTradingDay(date: LocalDate): Boolean =
        date.dayOfWeek != DayOfWeek.SATURDAY && date.dayOfWeek != DayOfWeek.SUNDAY && !isHoliday(date)

    fun closeTime(date: LocalDate): LocalTime = earlyClose(date) ?: regularClose

    fun nextTradingDay(date: LocalDate): LocalDate {
        var d = date.plusDays(1)
        while (!isTradingDay(d)) d = d.plusDays(1)
        return d
    }

    fun previousTradingDay(date: LocalDate): LocalDate {
        var d = date.minusDays(1)
        while (!isTradingDay(d)) d = d.minusDays(1)
        return d
    }

    /** Adds [sessions] trading sessions to [date] (session-based offsets, never calendar days). */
    fun plusSessions(date: LocalDate, sessions: Int): LocalDate {
        require(sessions >= 0)
        var d = date
        repeat(sessions) { d = nextTradingDay(d) }
        return d
    }

    fun sessionsBetween(fromExclusive: LocalDate, toInclusive: LocalDate): Int {
        var count = 0
        var d = fromExclusive
        while (d < toInclusive) {
            d = d.plusDays(1)
            if (isTradingDay(d)) count++
        }
        return count
    }
}

internal object HolidayRules {
    fun nthWeekday(year: Int, month: Month, day: DayOfWeek, n: Int): LocalDate =
        LocalDate.of(year, month, 1).with(TemporalAdjusters.dayOfWeekInMonth(n, day))

    fun lastWeekday(year: Int, month: Month, day: DayOfWeek): LocalDate =
        LocalDate.of(year, month, 1).with(TemporalAdjusters.lastInMonth(day))

    /** Anonymous Gregorian algorithm (Meeus/Jones/Butcher). */
    fun easterSunday(year: Int): LocalDate {
        val a = year % 19
        val b = year / 100
        val c = year % 100
        val d = b / 4
        val e = b % 4
        val f = (b + 8) / 25
        val g = (b - f + 1) / 3
        val h = (19 * a + b - d - g + 15) % 30
        val i = c / 4
        val k = c % 4
        val l = (32 + 2 * e + 2 * i - h - k) % 7
        val m = (a + 11 * h + 22 * l) / 451
        val month = (h + l - 7 * m + 114) / 31
        val day = ((h + l - 7 * m + 114) % 31) + 1
        return LocalDate.of(year, month, day)
    }

    /** US federal-style observance: Saturday -> Friday, Sunday -> Monday. */
    fun observed(date: LocalDate): LocalDate = when (date.dayOfWeek) {
        DayOfWeek.SATURDAY -> date.minusDays(1)
        DayOfWeek.SUNDAY -> date.plusDays(1)
        else -> date
    }
}

/** NYSE / Nasdaq calendar. */
class NyseCalendar(private val extraClosures: Set<LocalDate> = KNOWN_SPECIAL_CLOSURES) : TradingCalendar {
    override val exchange = "NYSE"
    override val zone: ZoneId = ZoneId.of("America/New_York")
    override val regularOpen: LocalTime = LocalTime.of(9, 30)
    override val regularClose: LocalTime = LocalTime.of(16, 0)

    private val cache = HashMap<Int, Set<LocalDate>>()

    fun holidays(year: Int): Set<LocalDate> = cache.getOrPut(year) {
        buildSet {
            // New Year's Day: Sunday -> Monday; Saturday -> not observed on the previous Friday (NYSE rule).
            val ny = LocalDate.of(year, 1, 1)
            when (ny.dayOfWeek) {
                DayOfWeek.SUNDAY -> add(ny.plusDays(1))
                DayOfWeek.SATURDAY -> Unit
                else -> add(ny)
            }
            add(HolidayRules.nthWeekday(year, Month.JANUARY, DayOfWeek.MONDAY, 3)) // MLK Day
            add(HolidayRules.nthWeekday(year, Month.FEBRUARY, DayOfWeek.MONDAY, 3)) // Washington's Birthday
            add(HolidayRules.easterSunday(year).minusDays(2)) // Good Friday
            add(HolidayRules.lastWeekday(year, Month.MAY, DayOfWeek.MONDAY)) // Memorial Day
            if (year >= 2022) add(HolidayRules.observed(LocalDate.of(year, 6, 19))) // Juneteenth
            add(HolidayRules.observed(LocalDate.of(year, 7, 4))) // Independence Day
            add(HolidayRules.nthWeekday(year, Month.SEPTEMBER, DayOfWeek.MONDAY, 1)) // Labor Day
            add(HolidayRules.nthWeekday(year, Month.NOVEMBER, DayOfWeek.THURSDAY, 4)) // Thanksgiving
            add(HolidayRules.observed(LocalDate.of(year, 12, 25))) // Christmas
        }
    }

    override fun isHoliday(date: LocalDate): Boolean = date in holidays(date.year) || date in extraClosures

    override fun earlyClose(date: LocalDate): LocalTime? {
        if (!isTradingDay(date)) return null
        val year = date.year
        val thanksgiving = HolidayRules.nthWeekday(year, Month.NOVEMBER, DayOfWeek.THURSDAY, 4)
        val onePm = LocalTime.of(13, 0)
        return when {
            date == thanksgiving.plusDays(1) -> onePm
            date.month == Month.DECEMBER && date.dayOfMonth == 24 -> onePm
            date.month == Month.JULY && date.dayOfMonth == 3 && date.dayOfWeek != DayOfWeek.FRIDAY -> onePm
            else -> null
        }
    }

    companion object {
        /** Unscheduled closures that rules cannot derive (national days of mourning). */
        val KNOWN_SPECIAL_CLOSURES: Set<LocalDate> = setOf(
            LocalDate.of(2018, 12, 5), // President G.H.W. Bush
            LocalDate.of(2025, 1, 9), // President Carter
        )
    }
}

/** Deutsche Börse Xetra calendar. */
class XetraCalendar : TradingCalendar {
    override val exchange = "XETRA"
    override val zone: ZoneId = ZoneId.of("Europe/Berlin")
    override val regularOpen: LocalTime = LocalTime.of(9, 0)
    override val regularClose: LocalTime = LocalTime.of(17, 30)

    override fun isHoliday(date: LocalDate): Boolean {
        val easter = HolidayRules.easterSunday(date.year)
        return date == easter.minusDays(2) || date == easter.plusDays(1) ||
            (date.monthValue == 1 && date.dayOfMonth == 1) ||
            (date.monthValue == 5 && date.dayOfMonth == 1) ||
            (date.monthValue == 12 && date.dayOfMonth in setOf(24, 25, 26, 31))
    }
}

/** London Stock Exchange calendar (England & Wales bank holidays). */
class LseCalendar : TradingCalendar {
    override val exchange = "LSE"
    override val zone: ZoneId = ZoneId.of("Europe/London")
    override val regularOpen: LocalTime = LocalTime.of(8, 0)
    override val regularClose: LocalTime = LocalTime.of(16, 30)

    override fun isHoliday(date: LocalDate): Boolean {
        val y = date.year
        val easter = HolidayRules.easterSunday(y)
        val newYear = LocalDate.of(y, 1, 1).let {
            when (it.dayOfWeek) { DayOfWeek.SATURDAY -> it.plusDays(2); DayOfWeek.SUNDAY -> it.plusDays(1); else -> it }
        }
        val xmas = LocalDate.of(y, 12, 25)
        val (xmasObs, boxingObs) = when (xmas.dayOfWeek) {
            DayOfWeek.FRIDAY -> xmas to xmas.plusDays(3)
            DayOfWeek.SATURDAY -> xmas.plusDays(2) to xmas.plusDays(3)
            DayOfWeek.SUNDAY -> xmas.plusDays(2) to xmas.plusDays(1)
            else -> xmas to xmas.plusDays(1)
        }
        return date == newYear || date == easter.minusDays(2) || date == easter.plusDays(1) ||
            date == HolidayRules.nthWeekday(y, Month.MAY, DayOfWeek.MONDAY, 1) ||
            date == HolidayRules.lastWeekday(y, Month.MAY, DayOfWeek.MONDAY) ||
            date == HolidayRules.lastWeekday(y, Month.AUGUST, DayOfWeek.MONDAY) ||
            date == xmasObs || date == boxingObs
    }
}

object Calendars {
    val NYSE: TradingCalendar = NyseCalendar()
    val XETRA: TradingCalendar = XetraCalendar()
    val LSE: TradingCalendar = LseCalendar()

    fun forExchange(exchange: String): TradingCalendar = when (exchange.uppercase()) {
        "XETRA", "GER", "FRA" -> XETRA
        "LSE", "LON" -> LSE
        else -> NYSE
    }
}
