package com.zephyr.breeze

import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.util.UUID

internal fun hlsHex(vararg values: String): String =
    MessageDigest.getInstance("SHA-256").digest(values.joinToString("|").toByteArray(Charsets.UTF_8))
        .joinToString("") { "%02x".format(it) }

internal fun hlsToken(): String = UUID.randomUUID().toString()

internal data class HlsBinding(val resourceId: String, val assetId: String, val generation: String) {
    fun map() = mapOf("resourceId" to resourceId, "assetId" to assetId, "generation" to generation)

    companion object {
        private val resource = Regex("[a-f0-9]{64}")
        private val token = Regex("[a-f0-9-]{36}")

        fun parse(raw: Map<*, *>, requiresResource: Boolean = true): HlsBinding? {
            val id = raw["resourceId"] as? String ?: ""
            val asset = raw["assetId"] as? String ?: return null
            val generation = raw["generation"] as? String ?: return null
            if ((requiresResource && !resource.matches(id)) || !token.matches(asset) || !token.matches(generation)) return null
            return HlsBinding(id, asset, generation)
        }
    }
}

internal data class HlsAsset(
    val binding: HlsBinding,
    val metadata: Map<String, Any>,
    val expected: String,
    val bytes: Long,
    val duration: Long,
    val ready: Boolean,
    val recoverable: Boolean,
) {
    fun publicRow(available: Boolean): Map<String, Any> = metadata.filterKeys {
        it !in setOf("wifiOnly", "attempt", "recoveryScope")
    } + binding.map() + mapOf(
        "format" to "hls", "bytes" to bytes, "durationMs" to duration,
        "available" to available, "filePresent" to available,
    )
}

/** IO-queue-only store. Atomically publish the index before retiring any prior package. */
internal class AndroidHlsStore(val root: File) {
    private data class Removal(val token: String, val source: String, val bindings: Set<HlsBinding>, val phase: String)
    private val index = AtomicFile(File(root, "index.json"))
    private val captionFileName = Regex("subtitle-[1-8]\\.vtt")
    private val fileName = Regex("(?:index|video|audio|audio-[1-8])\\.m3u8|" +
        "part-[1-9][0-9]*\\.(?:ts|m4s|mp4|aac|ac3|ec3|mp3|vtt|webvtt|key)|" +
        "captions\\.json|subtitle-[1-8]\\.vtt")
    private fun controlFile(file: File) = file.extension == "m3u8" ||
        file.name == "captions.json" || captionFileName.matches(file.name)
    private val assets: MutableMap<String, HlsAsset>
    private val removals: MutableMap<String, Removal>
    private val leases = mutableMapOf<String, Pair<HlsBinding, Any>>()

    init {
        check((root.mkdirs() || root.isDirectory) && root.canonicalPath == root.path)
        val stored = try {
            val buffer = index.openRead().use { it.readBytes() }
            check(buffer.size <= 16 * 1024 * 1024)
            JSONObject(String(buffer, Charsets.UTF_8))
        } catch (error: java.io.FileNotFoundException) {
            check(!index.baseFile.exists())
            null
        }
        if (stored != null) check(stored.getInt("version") == 1)
        assets = stored?.getJSONArray("assets")?.objects()?.associate { row ->
            val binding = HlsBinding.parse(row.getJSONObject("binding").map()) ?: error("Invalid HLS binding")
            binding.assetId to HlsAsset(
                binding,
                row.getJSONObject("metadata").map(),
                row.getString("expected"),
                row.getLong("bytes"),
                row.getLong("duration"),
                row.getBoolean("ready"),
                row.getBoolean("recoverable"),
            )
        }?.toMutableMap() ?: mutableMapOf()
        removals = stored?.getJSONArray("removals")?.objects()?.associate { row ->
            val token = row.getString("token")
            token to Removal(
                token, row.getString("source"),
                row.getJSONArray("bindings").objects().map {
                    HlsBinding.parse(it.map()) ?: error("Invalid HLS removal")
                }.toSet(),
                // The Dart import journal can replay a committed removal after
                // a restart. Expose the files while an interrupted plan settles.
                row.getString("phase").let { if (it == "staged") "rolledBack" else it },
            )
        }?.toMutableMap() ?: mutableMapOf()
        val orphans = assets.values.filter { !it.ready && !it.recoverable }
        if (orphans.isNotEmpty()) {
            val retained = assets - orphans.map { it.binding.assetId }.toSet()
            publish(retained, removals)
        }
        val ids = Regex("[a-f0-9-]{36}")
        root.listFiles().orEmpty().filter { ids.matches(it.name) && it.name !in assets }
            .forEach { it.deleteRecursively() }
    }

    private fun dir(binding: HlsBinding) = File(root, binding.assetId)

    fun createPackage(binding: HlsBinding): File = dir(binding).also {
        check(!it.exists() && it.mkdir() && it.canonicalPath == it.path)
    }

    // This verifies the package without interpreting a user-provided manifest
    // or permitting a symlink. Hash the generated manifests because those are
    // the only files able to control what a later player will request.
    fun seal(directory: File): Long {
        val children = directory.listFiles() ?: error("Missing HLS package")
        check(children.any { it.name == "index.m3u8" })
        val rows = JSONObject()
        var bytes = 0L
        for (file in children) {
            check(fileName.matches(file.name) && safeFile(file) && file.length() > 0)
            bytes += file.length()
            rows.put(file.name, if (controlFile(file)) digest(file) else file.length())
        }
        val record = File(directory, "package.json")
        record.outputStream().use { stream ->
            stream.write(rows.toString().toByteArray(Charsets.UTF_8))
            stream.fd.sync()
        }
        return bytes
    }

    private fun safeFile(file: File) = file.isFile && file.canonicalPath == file.path

    private fun digest(file: File): String {
        check(file.length() in 1..2_097_152)
        return MessageDigest.getInstance("SHA-256").digest(file.readBytes()).joinToString("") { "%02x".format(it) }
    }

    private fun available(asset: HlsAsset, complete: Boolean = false): Boolean = try {
        val directory = dir(asset.binding)
        val manifest = File(directory, "index.m3u8")
        val record = File(directory, "package.json")
        directory.canonicalPath == directory.path && safeFile(manifest) && safeFile(record) &&
            (!complete || run {
                check(record.length() in 1..2_097_152)
                val files = JSONObject(record.readText())
                files.has("index.m3u8") && files.keys().asSequence().all { name ->
                    val file = File(directory, name)
                    fileName.matches(name) && safeFile(file) &&
                        if (controlFile(file)) files.getString(name) == digest(file)
                        else files.getLong(name) > 0 && files.getLong(name) == file.length()
                }
            })
    } catch (_: Exception) {
        false
    }

    fun current(resource: String) = assets.values.firstOrNull { it.ready && it.binding.resourceId == resource }

    private fun hidden(asset: HlsAsset) =
        removals.values.any { it.phase == "staged" && asset.binding in it.bindings }

    fun list(): List<Map<String, Any>> = assets.values
        .filter { it.ready && !hidden(it) }.map { it.publicRow(available(it)) }

    fun stage(asset: HlsAsset) {
        check(assets.size < 10_000 &&
            (current(asset.binding.resourceId)?.binding?.generation ?: "") == asset.expected &&
            removals.values.none { it.source == asset.metadata["source"] && it.phase == "staged" } &&
            available(asset))
        publish(assets + (asset.binding.assetId to asset), removals)
    }

    fun commit(binding: HlsBinding): Map<String, Any> {
        val asset = assets[binding.assetId] ?: error("Missing HLS candidate")
        check(asset.binding == binding && !hidden(asset) && available(asset, complete = true))
        if (asset.ready) return asset.publicRow(true)
        val previous = current(binding.resourceId)
        check((previous?.binding?.generation ?: "") == asset.expected)
        if (previous != null) check(!leased(previous.binding))
        val next = assets - listOfNotNull(previous?.binding?.assetId).toSet() +
            (binding.assetId to asset.copy(ready = true))
        publish(next, removals)
        if (previous != null) dir(previous.binding).deleteRecursively()
        return asset.publicRow(true)
    }

    fun discard(binding: HlsBinding): Boolean {
        val asset = assets[binding.assetId] ?: return true
        require(asset.binding.generation == binding.generation && !asset.ready)
        publish(assets - binding.assetId, removals)
        dir(binding).deleteRecursively()
        return true
    }

    fun delete(binding: HlsBinding): Boolean {
        val asset = assets[binding.assetId] ?: return false
        check(asset.ready && asset.binding == binding && !hidden(asset) && !leased(binding))
        publish(assets - binding.assetId, removals)
        dir(binding).deleteRecursively()
        return true
    }

    fun snapshot(excluded: Set<String>): List<Map<String, Any>> = assets.values
        .filter { it.recoverable && it.binding.assetId !in excluded }
        .map {
            it.publicRow(it.ready && available(it)) +
                it.metadata.filterKeys { key -> key in setOf("wifiOnly", "attempt", "recoveryScope") } +
                ("status" to "staged")
        }

    fun acknowledge(binding: HlsBinding): Boolean {
        val asset = assets[binding.assetId] ?: return true
        check(asset.binding == binding)
        if (!asset.ready) return discard(binding)
        if (asset.recoverable) publish(assets + (binding.assetId to asset.copy(recoverable = false)), removals)
        return true
    }

    fun acquire(binding: HlsBinding, owner: Any): Pair<String, File> {
        val asset = assets[binding.assetId]
        check(asset != null && asset.ready && asset.binding == binding && !hidden(asset) && available(asset, complete = true))
        val token = hlsToken()
        leases[token] = binding to owner
        return token to File(dir(binding), "index.m3u8")
    }

    fun captions(binding: HlsBinding, token: String, owner: Any): List<Map<String, String>> {
        check(leases[token]?.let { it.first == binding && it.second === owner } == true)
        val packageDirectory = dir(binding)
        val sidecar = File(packageDirectory, "captions.json")
        if (!safeFile(sidecar) || sidecar.length() !in 1..8192) return emptyList()
        return JSONArray(sidecar.readText()).objects().mapNotNull {
            val name = it.optString("file")
            val label = it.optString("label")
            val caption = File(packageDirectory, name)
            if (!captionFileName.matches(name) || label.isBlank() || label.length > 128 ||
                !safeFile(caption) || caption.length() !in 1L..HlsWebVtt.MAX_FILE_BYTES.toLong()) null
            else mapOf("name" to label, "fileURL" to caption.toURI().toASCIIString())
        }.also { check(it.size <= 8) }
    }

    fun release(binding: HlsBinding, token: String, owner: Any): Boolean {
        val current = leases[token] ?: return true
        check(current.first == binding && current.second === owner)
        leases.remove(token)
        return true
    }

    fun releaseOwner(owner: Any) {
        leases.entries.removeAll { it.value.second === owner }
    }

    private fun leased(binding: HlsBinding) = leases.values.any { it.first == binding }

    fun hideTasks(keys: Set<String>): Boolean {
        val next = assets.mapValues { (_, asset) ->
            if (asset.metadata["taskKey"] in keys) asset.copy(metadata = asset.metadata + ("showTask" to false))
            else asset
        }
        if (next != assets) publish(next, removals)
        return true
    }

    fun stageRemoval(source: String, bindings: Set<HlsBinding>): String {
        val previous = removals.values.firstOrNull { it.source == source && it.phase == "staged" }
        if (previous != null) {
            check(previous.bindings == bindings)
            return previous.token
        }
        check(bindings.isNotEmpty() && bindings.all { binding ->
            val asset = assets[binding.assetId]
            asset?.binding == binding && asset.ready && asset.metadata["source"] == source && !leased(binding)
        })
        val token = hlsToken()
        val next = removals.toMutableMap()
        // Retain recovery tokens for only the most recent completed operations.
        if (next.size >= 2048) {
            val old = next.values.firstOrNull { it.phase != "staged" } ?: error("Too many removals")
            next.remove(old.token)
        }
        next[token] = Removal(token, source, bindings, "staged")
        publish(assets, next)
        return token
    }

    fun finishRemoval(token: String, committed: Boolean): Boolean {
        val row = removals[token] ?: return false
        if (row.phase == "committed") return committed
        if (!committed && row.phase == "rolledBack") return true
        val selected = if (committed) row.bindings.filter {
            val current = assets[it.assetId]
            current?.binding == it && !leased(it)
        } else emptyList()
        if (committed) check(row.bindings.none(::leased))
        val next = assets - selected.map { it.assetId }.toSet()
        val phase = if (committed) "committed" else "rolledBack"
        publish(next, removals + (token to row.copy(phase = phase)))
        selected.forEach { dir(it).deleteRecursively() }
        return true
    }

    private fun publish(nextAssets: Map<String, HlsAsset>, nextRemovals: Map<String, Removal>) {
        val savedAssets = nextAssets.toMap()
        val savedRemovals = nextRemovals.toMap()
        val value = JSONObject()
            .put("version", 1)
            .put("assets", JSONArray(savedAssets.values.map {
                JSONObject().put("binding", JSONObject(it.binding.map()))
                    .put("metadata", JSONObject(it.metadata)).put("expected", it.expected)
                    .put("bytes", it.bytes).put("duration", it.duration).put("ready", it.ready)
                    .put("recoverable", it.recoverable)
            }))
            .put("removals", JSONArray(savedRemovals.values.map {
                JSONObject().put("token", it.token).put("source", it.source).put("phase", it.phase)
                    .put("bindings", JSONArray(it.bindings.map { binding -> JSONObject(binding.map()) }))
            }))
        val data = value.toString().toByteArray(Charsets.UTF_8)
        check(data.size <= 16 * 1024 * 1024)
        val stream = index.startWrite()
        try {
            stream.write(data)
            index.finishWrite(stream)
        } catch (error: Exception) {
            index.failWrite(stream)
            throw error
        }
        assets.clear()
        assets.putAll(savedAssets)
        removals.clear()
        removals.putAll(savedRemovals)
    }

    private fun JSONArray.objects() = (0 until length()).map(::getJSONObject)
    private fun JSONObject.map() = keys().asSequence().associateWith { name -> get(name) }
}
