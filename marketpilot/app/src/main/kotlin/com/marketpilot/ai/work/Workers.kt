package com.marketpilot.ai.work

import android.content.Context
import androidx.hilt.work.HiltWorker
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.marketpilot.core.common.AppClock
import com.marketpilot.core.datastore.AppSettings
import com.marketpilot.data.repositories.AlertNotifier
import com.marketpilot.data.repositories.RefreshEngine
import com.marketpilot.data.repositories.RefreshOutcome
import com.marketpilot.data.repositories.RefreshTrigger
import com.marketpilot.data.repositories.SettingsRepository
import com.marketpilot.feature.settings.ScheduleUpdater
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import dagger.hilt.android.qualifiers.ApplicationContext
import java.time.Duration
import java.time.ZonedDateTime
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Opportunistic background refresh. Android decides the actual execution time (Doze, App Standby,
 * battery optimisation): this is best-effort, never guaranteed at an exact time.
 */
@HiltWorker
class MarketRefreshWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val engine: RefreshEngine,
    private val settings: SettingsRepository,
) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val s = settings.current()
        if (!s.onboardingCompleted || !s.notifications.backgroundRefreshEnabled) return Result.success()
        return when (val r = engine.refresh(RefreshTrigger.BACKGROUND)) {
            RefreshOutcome.AlreadyRunning -> Result.success()
            is RefreshOutcome.Done -> if (r.status == "COMPLETED" || r.status == "PARTIAL") Result.success() else Result.retry()
        }
    }
}

@HiltWorker
class DailyReminderWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val settings: SettingsRepository,
    private val notifier: AlertNotifier,
) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val s = settings.current()
        if (s.notifications.dailyReminderEnabled) {
            notifier.notify(7001, "Analisi giornaliera", "Apri MarketPilot e premi AGGIORNA MERCATO per il quadro di oggi. Ricorda: NESSUN TRADE è sempre un'opzione valida.")
        }
        return Result.success()
    }
}

@Singleton
class WorkScheduler @Inject constructor(@ApplicationContext private val context: Context, private val clock: AppClock) : ScheduleUpdater {
    override fun apply(settings: AppSettings) {
        val wm = WorkManager.getInstance(context)
        if (settings.notifications.backgroundRefreshEnabled) {
            val req = PeriodicWorkRequestBuilder<MarketRefreshWorker>(24, TimeUnit.HOURS, 4, TimeUnit.HOURS)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).setRequiresBatteryNotLow(true).build())
                .build()
            wm.enqueueUniquePeriodicWork(REFRESH, ExistingPeriodicWorkPolicy.KEEP, req)
        } else wm.cancelUniqueWork(REFRESH)
        if (settings.notifications.dailyReminderEnabled) {
            val now = clock.now().atZone(AppClock.DISPLAY_ZONE)
            var next = now.withHour(settings.notifications.dailyReminderHour).withMinute(0).withSecond(0).withNano(0)
            if (!next.isAfter(now)) next = next.plusDays(1)
            val delay = Duration.between(now, next)
            val req = PeriodicWorkRequestBuilder<DailyReminderWorker>(24, TimeUnit.HOURS).setInitialDelay(delay.toMinutes(), TimeUnit.MINUTES).build()
            wm.enqueueUniquePeriodicWork(REMINDER, ExistingPeriodicWorkPolicy.UPDATE, req)
        } else wm.cancelUniqueWork(REMINDER)
    }

    companion object {
        const val REFRESH = "marketpilot_daily_refresh"
        const val REMINDER = "marketpilot_daily_reminder"
    }
}

fun ZonedDateTime.atHour(h: Int): ZonedDateTime = withHour(h).withMinute(0).withSecond(0).withNano(0)
