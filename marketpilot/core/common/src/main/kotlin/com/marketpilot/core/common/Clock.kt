package com.marketpilot.core.common

import java.time.Instant
import java.time.ZoneId

/** Injectable time source (tests use a fixed clock). */
fun interface AppClock {
    fun now(): Instant

    companion object {
        val SYSTEM = AppClock { Instant.now() }
        val DISPLAY_ZONE: ZoneId = ZoneId.of("Europe/Rome")
    }
}
