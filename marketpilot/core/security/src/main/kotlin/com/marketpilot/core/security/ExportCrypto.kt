package com.marketpilot.core.security

import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * Password-based encryption for backup files: PBKDF2-HMAC-SHA256 (210k iterations) + AES-256-GCM.
 * Format: "MPX1" | salt(16) | iv(12) | ciphertext+tag.
 */
object ExportCrypto {
    private const val MAGIC = "MPX1"
    private const val ITERATIONS = 210_000

    private fun derive(password: CharArray, salt: ByteArray): SecretKeySpec {
        val f = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        val bytes = f.generateSecret(PBEKeySpec(password, salt, ITERATIONS, 256)).encoded
        return SecretKeySpec(bytes, "AES")
    }

    fun encrypt(plain: ByteArray, password: CharArray): ByteArray {
        require(password.size >= 8) { "La password deve avere almeno 8 caratteri" }
        val rnd = SecureRandom()
        val salt = ByteArray(16).also(rnd::nextBytes)
        val iv = ByteArray(12).also(rnd::nextBytes)
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.ENCRYPT_MODE, derive(password, salt), GCMParameterSpec(128, iv))
        return MAGIC.toByteArray() + salt + iv + c.doFinal(plain)
    }

    fun isEncrypted(data: ByteArray): Boolean = data.size > 32 && String(data.copyOfRange(0, 4)) == MAGIC

    fun decrypt(data: ByteArray, password: CharArray): ByteArray {
        require(isEncrypted(data)) { "File non cifrato o formato non riconosciuto" }
        val salt = data.copyOfRange(4, 20)
        val iv = data.copyOfRange(20, 32)
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.DECRYPT_MODE, derive(password, salt), GCMParameterSpec(128, iv))
        return c.doFinal(data.copyOfRange(32, data.size))
    }
}
