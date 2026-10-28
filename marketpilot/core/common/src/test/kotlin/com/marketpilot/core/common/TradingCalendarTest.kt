package com.marketpilot.core.common

import com.marketpilot.core.model.Freshness
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class TradingCalendarTest {
    private val nyse = NyseCalendar()

    @Test fun nyseHolidays2026() {
        val expected = listOf(
            "2026-01-01", "2026-01-19", "2026-02-16", "2026-04-03", "2026-05-25",
            "2026-06-19", "2026-07-03", "2026-09-07", "2026-11-26", "2026-12-25",
        ).map(LocalDate::parse).toSet()
        assertEquals(expected, nyse.holidays(2026))
    }

    @Test fun saturdayNewYearIsNotObservedOnFriday() {
        assertTrue(nyse.isTradingDay(LocalDate.of(2021, 12, 31)))
        assertFalse(nyse.isTradingDay(LocalDate.of(2023, 1, 2))) // Sunday 2023-01-01 -> Monday
    }

    @Test fun easterIsComputedCorrectly() {
        assertEquals(LocalDate.of(2024, 3, 31), HolidayRules.easterSunday(2024))
        assertEquals(LocalDate.of(2025, 4, 20), HolidayRules.easterSunday(2025))
        assertEquals(LocalDate.of(2026, 4, 5), HolidayRules.easterSunday(2026))
    }

    @Test fun earlyCloses() {
        assertEquals(LocalTime.of(13, 0), nyse.earlyClose(LocalDate.of(2026, 11, 27)))
        assertEquals(LocalTime.of(13, 0), nyse.earlyClose(LocalDate.of(2026, 12, 24)))
        assertNull(nyse.earlyClose(LocalDate.of(2026, 7, 3))) // holiday itself
        assertEquals(LocalTime.of(13, 0), nyse.earlyClose(LocalDate.of(2025, 7, 3)))
    }

    @Test fun sessionOffsetsSkipWeekendsAndHolidays() {
        // Thu 2026-04-02 + 1 session = Mon 2026-04-06 (Good Friday + weekend skipped)
        assertEquals(LocalDate.of(2026, 4, 6), nyse.plusSessions(LocalDate.of(2026, 4, 2), 1))
        assertEquals(5, nyse.sessionsBetween(LocalDate.of(2026, 3, 27), LocalDate.of(2026, 4, 3).plusDays(3))) // 30,31,1,2,6
    }

    @Test fun xetraAndLseHolidays() {
        assertFalse(Calendars.XETRA.isTradingDay(LocalDate.of(2026, 12, 24)))
        assertFalse(Calendars.XETRA.isTradingDay(LocalDate.of(2026, 4, 6))) // Easter Monday
        assertFalse(Calendars.LSE.isTradingDay(LocalDate.of(2026, 8, 31))) // Summer bank holiday
        assertTrue(Calendars.LSE.isTradingDay(LocalDate.of(2026, 8, 28)))
    }

    @Test fun sessionPhases() {
        // 2026-10-27 is a Tuesday. 14:00Z = 10:00 New York (EDT)
        assertEquals(SessionPhase.OPEN, MarketSessions.status(nyse, Instant.parse("2026-10-27T14:00:00Z")).phase)
        assertEquals(SessionPhase.PRE_MARKET, MarketSessions.status(nyse, Instant.parse("2026-10-27T12:00:00Z")).phase)
        assertEquals(SessionPhase.AFTER_HOURS, MarketSessions.status(nyse, Instant.parse("2026-10-27T21:00:00Z")).phase)
        assertEquals(SessionPhase.WEEKEND, MarketSessions.status(nyse, Instant.parse("2026-10-31T15:00:00Z")).phase)
        assertEquals(SessionPhase.HOLIDAY, MarketSessions.status(nyse, Instant.parse("2026-11-26T15:00:00Z")).phase)
    }

    @Test fun lastCompletedSessionRespectsCloseAndSettle() {
        val during = Instant.parse("2026-10-27T15:00:00Z")
        assertEquals(LocalDate.of(2026, 10, 26), MarketSessions.lastCompletedSession(nyse, during))
        val after = Instant.parse("2026-10-27T21:00:00Z") // 17:00 NY, after close + 30m
        assertEquals(LocalDate.of(2026, 10, 27), MarketSessions.lastCompletedSession(nyse, after))
        val monday = Instant.parse("2026-11-02T13:00:00Z")
        assertEquals(LocalDate.of(2026, 10, 30), MarketSessions.lastCompletedSession(nyse, monday))
    }

    @Test fun freshnessClassification() {
        val now = Instant.parse("2026-10-28T10:00:00Z") // Wed early morning NY: last completed = Tue 27
        assertEquals(Freshness.END_OF_DAY, MarketSessions.classifyBarDate(nyse, LocalDate.of(2026, 10, 27), now))
        assertEquals(Freshness.STALE, MarketSessions.classifyBarDate(nyse, LocalDate.of(2026, 10, 23), now))
        assertEquals(Freshness.UNKNOWN, MarketSessions.classifyBarDate(nyse, null, now))
        val open = Instant.parse("2026-10-28T15:00:00Z")
        assertEquals(Freshness.LIVE, MarketSessions.classify(nyse, open.minusSeconds(30), open))
        assertEquals(Freshness.DELAYED, MarketSessions.classify(nyse, open.minusSeconds(1200), open))
    }

    @Test fun catalogKeepsUsAndUcitsDistinct() {
        val sxr8 = InstrumentCatalog.byId("SXR8:XETRA")!!
        val cspx = InstrumentCatalog.byId("CSPX:LSE")!!
        val spy = InstrumentCatalog.byId(InstrumentCatalog.SPY)!!
        assertTrue(sxr8.isUcits && cspx.isUcits && !spy.isUcits)
        assertEquals(sxr8.isin, cspx.isin) // same fund, different listing/currency
        assertEquals("EUR", sxr8.currency); assertEquals("USD", cspx.currency)
        assertTrue(InstrumentCatalog.ucitsEtfs.all { it.isin!!.startsWith("IE") })
        assertTrue(InstrumentCatalog.all.map { it.id }.let { it.size == it.toSet().size })
    }
}
