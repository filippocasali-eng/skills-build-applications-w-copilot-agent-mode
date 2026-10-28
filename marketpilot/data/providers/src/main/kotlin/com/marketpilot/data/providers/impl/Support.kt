package com.marketpilot.data.providers.impl

import com.marketpilot.core.model.DataQuality
import com.marketpilot.core.model.Freshness
import com.marketpilot.core.model.ProviderDescriptor
import com.marketpilot.core.model.ProviderError
import com.marketpilot.core.model.ProviderErrorKind
import com.marketpilot.core.model.ProviderResult
import com.marketpilot.core.model.RateLimitInfo
import com.marketpilot.core.model.SourceInfo
import com.marketpilot.core.network.FetchResult
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.longOrNull
import org.w3c.dom.Document
import org.w3c.dom.Element
import org.w3c.dom.Node
import java.io.ByteArrayInputStream
import java.time.Instant
import javax.xml.parsers.DocumentBuilderFactory

internal val lenientJson = Json { ignoreUnknownKeys = true; isLenient = true }

internal fun source(d: ProviderDescriptor, url: String) = SourceInfo(d.id, d.displayName, redactSecrets(url))

/** Removes API keys/tokens from URLs before they are stored or displayed. */
fun redactSecrets(url: String): String =
    url.replace(Regex("(?i)(apikey|token|api_key|access_token)=[^&]+"), "$1=***")

internal fun <T> fail(d: ProviderDescriptor, url: String, now: Instant, error: ProviderError, instrumentId: String? = null, retryAfter: Long? = null): ProviderResult<T> =
    ProviderResult.failure(source(d, url), error, now, instrumentId, retryAfter?.let { RateLimitInfo(retryAfterSeconds = it) })

internal fun <T> fromFetchFailure(d: ProviderDescriptor, url: String, now: Instant, f: FetchResult.Failed, instrumentId: String? = null): ProviderResult<T> =
    fail(d, url, now, f.error, instrumentId, f.retryAfterSeconds)

internal fun <T> ok(
    d: ProviderDescriptor, url: String, data: T, observedAt: Instant?, now: Instant, freshness: Freshness,
    currency: String? = null, instrumentId: String? = null, quality: DataQuality = DataQuality(),
): ProviderResult<T> = ProviderResult(data, source(d, url), observedAt, now, freshness, currency, instrumentId, quality)

internal fun parseError(msg: String) = ProviderError(ProviderErrorKind.PARSE, msg)

/** Detects HTML bot-verification pages returned instead of data. */
internal fun looksLikeBotWall(body: String): Boolean {
    val head = body.take(2000).lowercase()
    return head.contains("<html") && (head.contains("requires javascript") || head.contains("verify your browser") || head.contains("captcha"))
}

// --- JSON helpers -------------------------------------------------------------------------------
internal operator fun JsonElement?.get(key: String): JsonElement? = (this as? JsonObject)?.get(key)
internal operator fun JsonElement?.get(index: Int): JsonElement? = (this as? JsonArray)?.getOrNull(index)
internal val JsonElement?.str: String? get() = (this as? JsonPrimitive)?.takeIf { it !is JsonNull }?.content
internal val JsonElement?.dbl: Double? get() = (this as? JsonPrimitive)?.let { if (it is JsonNull) null else it.doubleOrNull ?: it.content.toDoubleOrNull() }
internal val JsonElement?.lng: Long? get() = (this as? JsonPrimitive)?.let { if (it is JsonNull) null else it.longOrNull ?: it.content.toDoubleOrNull()?.toLong() }
internal val JsonElement?.arr: List<JsonElement> get() = (this as? JsonArray) ?: emptyList()

// --- XML helpers (external entities disabled to prevent XXE) ------------------------------------
internal object SafeXml {
    fun parse(xml: String): Document {
        val f = DocumentBuilderFactory.newInstance()
        f.isNamespaceAware = false
        f.isExpandEntityReferences = false
        runCatching { f.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true) }
        runCatching { f.setFeature("http://xml.org/sax/features/external-general-entities", false) }
        runCatching { f.setFeature("http://xml.org/sax/features/external-parameter-entities", false) }
        val cleaned = xml.trimStart('﻿', ' ', '\n', '\r', '\t')
        return f.newDocumentBuilder().parse(ByteArrayInputStream(cleaned.toByteArray(Charsets.UTF_8)))
    }
}

internal fun Element.children(name: String): List<Element> {
    val out = mutableListOf<Element>()
    val nodes = childNodes
    for (i in 0 until nodes.length) {
        val n = nodes.item(i)
        if (n.nodeType == Node.ELEMENT_NODE && (n.nodeName == name || n.nodeName.substringAfter(':') == name)) out += n as Element
    }
    return out
}

internal fun Element.child(name: String): Element? = children(name).firstOrNull()

internal fun Element.descendants(name: String): List<Element> {
    val nl = getElementsByTagName("*")
    return (0 until nl.length).map { nl.item(it) as Element }.filter { it.nodeName == name || it.nodeName.substringAfter(':') == name }
}

internal fun Element?.text(): String? = this?.textContent?.trim()?.takeIf { it.isNotEmpty() }

/** Reads `<tag><value>x</value></tag>` (SEC ownership documents) or `<tag>x</tag>`. */
internal fun Element?.valueOf(name: String): String? {
    val e = this?.child(name) ?: return null
    return e.child("value").text() ?: e.text()
}

internal fun splitCsvLine(line: String): List<String> {
    val out = mutableListOf<String>()
    val sb = StringBuilder()
    var quoted = false
    for (ch in line) {
        when {
            ch == '"' -> quoted = !quoted
            ch == ',' && !quoted -> { out += sb.toString(); sb.clear() }
            else -> sb.append(ch)
        }
    }
    out += sb.toString()
    return out.map { it.trim() }
}
