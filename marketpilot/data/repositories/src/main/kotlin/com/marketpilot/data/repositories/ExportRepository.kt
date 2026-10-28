package com.marketpilot.data.repositories

import androidx.room.withTransaction
import com.marketpilot.core.common.AppClock
import com.marketpilot.core.database.AlertEntity
import com.marketpilot.core.database.DecisionSnapshotEntity
import com.marketpilot.core.database.EvaluationResultEntity
import com.marketpilot.core.database.InstrumentEntity
import com.marketpilot.core.database.JournalEntryEntity
import com.marketpilot.core.database.LedgerEntryEntity
import com.marketpilot.core.database.MarketPilotDatabase
import com.marketpilot.core.database.PaperFillEntity
import com.marketpilot.core.database.PaperOrderEntity
import com.marketpilot.core.database.WatchlistEntity
import com.marketpilot.core.datastore.AppSettings
import com.marketpilot.core.security.ExportCrypto
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/** Portable backup. API keys and other secrets are never exported. */
@Serializable
data class ExportBundle(
    val format: String = "marketpilot-export",
    val version: Int = 1,
    val exportedAt: String,
    val settings: AppSettings,
    val userInstruments: List<InstrumentEntity>,
    val watchlist: List<WatchlistEntity>,
    val ledger: List<LedgerEntryEntity>,
    val orders: List<PaperOrderEntity>,
    val fills: List<PaperFillEntity>,
    val journal: List<JournalEntryEntity>,
    val alerts: List<AlertEntity>,
    val snapshots: List<DecisionSnapshotEntity>,
    val evaluations: List<EvaluationResultEntity>,
)

data class ImportReport(val ledger: Int, val orders: Int, val journal: Int, val snapshots: Int)

@Singleton
class ExportRepository @Inject constructor(
    private val db: MarketPilotDatabase,
    private val settings: SettingsRepository,
    private val portfolio: PortfolioRepository,
    private val clock: AppClock,
) {
    suspend fun export(password: CharArray?): ByteArray {
        val bundle = ExportBundle(
            exportedAt = clock.now().toString(),
            settings = settings.current().copy(deviceId = ""),
            userInstruments = db.instrumentDao().all().filter { it.userAdded },
            watchlist = db.watchlistDao().all(),
            ledger = db.ledgerDao().all(),
            orders = db.paperTradingDao().orders(),
            fills = db.paperTradingDao().fills(),
            journal = db.journalDao().all(),
            alerts = db.alertDao().all(),
            snapshots = db.decisionDao().snapshots(),
            evaluations = db.decisionDao().evaluations(),
        )
        val json = dbJson.encodeToString(ExportBundle.serializer(), bundle).toByteArray(Charsets.UTF_8)
        return if (password != null && password.isNotEmpty()) ExportCrypto.encrypt(json, password) else json
    }

    fun isEncrypted(data: ByteArray) = ExportCrypto.isEncrypted(data)

    /** Restores a backup, replacing the current user data (portfolio, orders, journal, watchlist, alerts). */
    suspend fun import(data: ByteArray, password: CharArray?): ImportReport {
        val plain = if (ExportCrypto.isEncrypted(data)) ExportCrypto.decrypt(data, password ?: CharArray(0)) else data
        val b = dbJson.decodeFromString(ExportBundle.serializer(), plain.toString(Charsets.UTF_8))
        require(b.format == "marketpilot-export") { "File non riconosciuto" }
        db.withTransaction {
            db.instrumentDao().upsert(b.userInstruments)
            b.watchlist.forEach { db.watchlistDao().upsert(it) }
            db.ledgerDao().clearForRestore()
            db.ledgerDao().append(b.ledger)
            db.paperTradingDao().clearFillsForRestore()
            db.paperTradingDao().clearOrdersForRestore()
            db.paperTradingDao().upsertOrders(b.orders)
            if (b.fills.isNotEmpty()) db.paperTradingDao().insertFills(b.fills)
            db.journalDao().insertAll(b.journal)
            db.alertDao().insertAll(b.alerts)
            db.decisionDao().insertSnapshots(b.snapshots)
            db.decisionDao().upsertEvaluations(b.evaluations)
        }
        val keepId = settings.current().deviceId
        settings.update { b.settings.copy(deviceId = keepId) }
        portfolio.rebuildPositions()
        return ImportReport(b.ledger.size, b.orders.size, b.journal.size, b.snapshots.size)
    }
}
