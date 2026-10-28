package com.marketpilot.data.repositories

import com.marketpilot.core.common.AppClock
import com.marketpilot.core.database.AlertEntity
import com.marketpilot.core.database.FetchMarkerEntity
import com.marketpilot.core.database.MarketPilotDatabase
import com.marketpilot.core.model.InsiderTransactionType
import kotlinx.coroutines.flow.Flow
import java.time.Duration
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton

/** Local notification sink (implemented with Android notifications in the app module). */
interface AlertNotifier {
    fun notify(id: Int, title: String, text: String)
}

enum class AlertType(val label: String) {
    PRICE_ABOVE("Prezzo sopra soglia"),
    PRICE_BELOW("Prezzo sotto soglia"),
    SCORE_ABOVE("Punteggio sopra soglia"),
}

/**
 * Evaluates alerts after each refresh. Delivery depends on Android scheduling (WorkManager may defer
 * background refreshes, battery optimisation may delay them): alerts are NOT real-time.
 */
@Singleton
class AlertRepository @Inject constructor(
    private val db: MarketPilotDatabase,
    private val market: MarketDataRepository,
    private val settings: SettingsRepository,
    private val notifier: AlertNotifier,
    private val clock: AppClock,
) {
    fun observe(): Flow<List<AlertEntity>> = db.alertDao().observe()

    suspend fun add(type: AlertType, instrumentId: String, threshold: Double) =
        db.alertDao().upsert(AlertEntity(type = type.name, instrumentId = instrumentId, threshold = threshold, direction = null, enabled = true, createdAtMs = clock.now().toEpochMilli(), lastTriggeredAtMs = null, lastMessage = null))

    suspend fun setEnabled(a: AlertEntity, enabled: Boolean) = db.alertDao().upsert(a.copy(enabled = enabled))
    suspend fun delete(id: Long) = db.alertDao().delete(id)

    private suspend fun once(key: String, within: Duration): Boolean {
        val m = db.cacheDao().marker("alert:$key")
        if (m != null && Duration.between(java.time.Instant.ofEpochMilli(m.lastFetchMs), clock.now()) < within) return false
        db.cacheDao().mark(FetchMarkerEntity("alert:$key", clock.now().toEpochMilli()))
        return true
    }

    /** Returns the number of notifications emitted. */
    suspend fun evaluate(newFills: Int): Int {
        val s = settings.current()
        if (!s.notifications.alertsEnabled) return 0
        var fired = 0
        val now = clock.now()
        for (a in db.alertDao().enabled()) {
            val id = a.instrumentId ?: continue
            val inst = market.instrument(id) ?: continue
            val last = market.candles(id).lastOrNull()
            val price = market.quote(id)?.quote?.price ?: last?.close ?: continue
            val score = db.analysisDao().latestStockScore(id)?.score
            val th = a.threshold ?: continue
            val hit = when (runCatching { AlertType.valueOf(a.type) }.getOrNull()) {
                AlertType.PRICE_ABOVE -> price >= th
                AlertType.PRICE_BELOW -> price <= th
                AlertType.SCORE_ABOVE -> score != null && score >= th
                null -> false
            }
            val recently = a.lastTriggeredAtMs?.let { Duration.between(java.time.Instant.ofEpochMilli(it), now) < Duration.ofHours(20) } ?: false
            if (hit && !recently) {
                val msg = "${inst.symbol}: ${AlertType.valueOf(a.type).label} (${"%.2f".format(a.threshold)}). Valore attuale: ${if (a.type == AlertType.SCORE_ABOVE.name) "%.0f".format(score) else "%.2f %s".format(price, inst.currency)}"
                notifier.notify(a.id.toInt(), "Avviso MarketPilot", msg)
                db.alertDao().upsert(a.copy(lastTriggeredAtMs = now.toEpochMilli(), lastMessage = msg))
                fired++
            }
        }
        if (newFills > 0 && once("fills:${now.toEpochMilli() / 60_000}", Duration.ofMinutes(1))) {
            notifier.notify(9001, "Ordini simulati eseguiti", "$newFills esecuzioni simulate registrate (stop/target/ordini). Nessun ordine reale è stato inviato.")
            fired++
        }
        // Watchlist: insider purchases and upcoming earnings (once per event)
        val today = now.atZone(AppClock.DISPLAY_ZONE).toLocalDate()
        for (id in market.watchlist()) {
            val inst = market.instrument(id) ?: continue
            val buys = db.alternativeDataDao().insidersFor(inst.symbol).filter {
                it.type == InsiderTransactionType.OPEN_MARKET_PURCHASE.name && !it.isRule10b51Plan && LocalDate.ofEpochDay(it.filingEpochDay) >= today.minusDays(3)
            }
            buys.firstOrNull()?.let { b ->
                if (once("insider:${b.accessionNumber}", Duration.ofDays(365))) {
                    notifier.notify(("ins" + b.accessionNumber).hashCode(), "Acquisto insider: ${inst.symbol}", "${b.insiderName} (${b.insiderRole}) ha acquistato sul mercato. Fonte: SEC Form 4.")
                    fired++
                }
            }
            db.alternativeDataDao().nextEarnings(inst.symbol, today.toEpochDay())?.let { e ->
                val d = LocalDate.ofEpochDay(e.epochDay)
                if (d <= today.plusDays(5) && once("earn:${inst.symbol}:$d", Duration.ofDays(30))) {
                    notifier.notify(("earn" + inst.symbol).hashCode(), "Trimestrale in arrivo: ${inst.symbol}", "Risultati attesi il $d (fonte: ${e.providerId}). Rischio di gap sui prezzi.")
                    fired++
                }
            }
        }
        return fired
    }
}
