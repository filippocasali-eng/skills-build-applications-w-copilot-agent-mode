package com.marketpilot.core.security

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Names of user-supplied personal credentials. Nothing is bundled in the APK. */
enum class SecretKeyName { ALPHA_VANTAGE_API_KEY, FINNHUB_API_KEY, REDDIT_CLIENT_ID }

interface SecretStore {
    fun get(name: SecretKeyName): String?
    fun put(name: SecretKeyName, value: String?)
    fun isSet(name: SecretKeyName): Boolean = !get(name).isNullOrBlank()
}

/** AES-GCM encryption/decryption primitive (Android Keystore in production, plain JCA key in tests). */
interface CipherProvider {
    fun encrypt(plain: ByteArray): Pair<ByteArray, ByteArray> // iv, ciphertext
    fun decrypt(iv: ByteArray, cipherText: ByteArray): ByteArray
}

/**
 * AES-256-GCM key generated inside the Android Keystore (non-exportable). Only ciphertext is stored
 * in app-private SharedPreferences. Note: this protects secrets at rest on this device; it does not
 * make a shared secret embedded in an APK safe, which is why the app never ships one.
 */
class AndroidKeystoreCipher(private val alias: String = "marketpilot_secrets_v1") : CipherProvider {
    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getEntry(alias, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return gen.generateKey()
    }

    override fun encrypt(plain: ByteArray): Pair<ByteArray, ByteArray> {
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.ENCRYPT_MODE, key())
        return c.iv to c.doFinal(plain)
    }

    override fun decrypt(iv: ByteArray, cipherText: ByteArray): ByteArray {
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, iv))
        return c.doFinal(cipherText)
    }
}

class EncryptedSecretStore(private val prefs: SharedPreferences, private val cipher: CipherProvider) : SecretStore {
    constructor(context: Context) : this(context.getSharedPreferences("marketpilot_secrets", Context.MODE_PRIVATE), AndroidKeystoreCipher())

    override fun get(name: SecretKeyName): String? {
        val stored = prefs.getString(name.name, null) ?: return null
        val parts = stored.split(':')
        if (parts.size != 2) return null
        return runCatching {
            String(cipher.decrypt(Base64.decode(parts[0], Base64.NO_WRAP), Base64.decode(parts[1], Base64.NO_WRAP)), Charsets.UTF_8)
        }.getOrNull()
    }

    override fun put(name: SecretKeyName, value: String?) {
        val v = value?.trim()
        if (v.isNullOrEmpty()) {
            prefs.edit().remove(name.name).apply()
            return
        }
        val (iv, ct) = cipher.encrypt(v.toByteArray(Charsets.UTF_8))
        prefs.edit().putString(name.name, Base64.encodeToString(iv, Base64.NO_WRAP) + ":" + Base64.encodeToString(ct, Base64.NO_WRAP)).apply()
    }
}
