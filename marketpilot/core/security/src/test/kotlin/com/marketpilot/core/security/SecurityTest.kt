package com.marketpilot.core.security

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.spec.GCMParameterSpec
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** AndroidKeyStore is not available on the JVM, so the store is tested with an equivalent JCA AES-GCM key. */
private class TestCipher : CipherProvider {
    private val key = KeyGenerator.getInstance("AES").apply { init(256) }.generateKey()
    override fun encrypt(plain: ByteArray): Pair<ByteArray, ByteArray> {
        val c = Cipher.getInstance("AES/GCM/NoPadding"); c.init(Cipher.ENCRYPT_MODE, key); return c.iv to c.doFinal(plain)
    }
    override fun decrypt(iv: ByteArray, cipherText: ByteArray): ByteArray {
        val c = Cipher.getInstance("AES/GCM/NoPadding"); c.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, iv)); return c.doFinal(cipherText)
    }
}

@RunWith(RobolectricTestRunner::class)
class SecurityTest {
    @Test fun secretsAreStoredOnlyAsCiphertext() {
        val prefs = ApplicationProvider.getApplicationContext<Context>().getSharedPreferences("t", Context.MODE_PRIVATE)
        val store = EncryptedSecretStore(prefs, TestCipher())
        store.put(SecretKeyName.FINNHUB_API_KEY, "  my-secret-key  ")
        assertEquals("my-secret-key", store.get(SecretKeyName.FINNHUB_API_KEY))
        assertFalse(prefs.all.values.any { it.toString().contains("my-secret-key") })
        store.put(SecretKeyName.FINNHUB_API_KEY, "")
        assertNull(store.get(SecretKeyName.FINNHUB_API_KEY))
        assertFalse(store.isSet(SecretKeyName.REDDIT_CLIENT_ID))
    }

    @Test fun exportEncryptionRoundTripAndWrongPassword() {
        val data = "{\"ledger\":[1,2,3]}".toByteArray()
        val enc = ExportCrypto.encrypt(data, "correct horse".toCharArray())
        assertTrue(ExportCrypto.isEncrypted(enc))
        assertContentEquals(data, ExportCrypto.decrypt(enc, "correct horse".toCharArray()))
        assertFailsWith<Exception> { ExportCrypto.decrypt(enc, "wrong password".toCharArray()) }
        assertFailsWith<IllegalArgumentException> { ExportCrypto.encrypt(data, "short".toCharArray()) }
    }
}
