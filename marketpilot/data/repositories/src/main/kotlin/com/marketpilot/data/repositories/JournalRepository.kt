package com.marketpilot.data.repositories

import com.marketpilot.core.common.AppClock
import com.marketpilot.core.database.JournalEntryEntity
import com.marketpilot.core.database.MarketPilotDatabase
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class JournalRepository @Inject constructor(private val db: MarketPilotDatabase, private val clock: AppClock) {
    fun observe(): Flow<List<JournalEntryEntity>> = db.journalDao().observe()

    suspend fun save(
        id: Long?, title: String, body: String, instrumentId: String?, orderId: String?, account: String?,
        setup: String?, emotion: String?, lessons: String?, tags: List<String>,
    ): Long {
        val now = clock.now().toEpochMilli()
        val created = id?.let { existing -> db.journalDao().all().firstOrNull { it.id == existing }?.createdAtMs } ?: now
        return db.journalDao().upsert(
            JournalEntryEntity(id ?: 0, created, now, account, instrumentId, orderId, title.trim(), body.trim(), setup, emotion, lessons, tags.joinToString(",")),
        )
    }

    suspend fun delete(id: Long) = db.journalDao().delete(id)
}
