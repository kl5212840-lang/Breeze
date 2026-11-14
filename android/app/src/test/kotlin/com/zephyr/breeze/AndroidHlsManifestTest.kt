package com.zephyr.breeze

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.net.InetSocketAddress
import java.net.Proxy

class AndroidHlsManifestTest {
    @Test
    fun masterChoosesOneVariantAndKeepsItsAudioAndCaptions() {
        val manifest = HlsManifest.master(HlsManifest.read("""
            #EXTM3U
            #EXT-X-VERSION:6
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="original",NAME="Second",LANGUAGE="ja",DEFAULT=NO,AUTOSELECT=YES,CHANNELS="2",URI="audio/second.m3u8"
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="original",NAME="Default, English",LANGUAGE="en",DEFAULT=YES,URI="../audio/default.m3u8"
            #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="captions",NAME="English",LANGUAGE="en",URI="captions/en.m3u8"
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="other",NAME="Unselected",URI="audio/not-used.m3u8"
            #EXT-X-STREAM-INF:BANDWIDTH=150000,CODECS="avc1.4d4015"
            sd/index.m3u8
            #EXT-X-STREAM-INF:BANDWIDTH=1100000,AUDIO="original",SUBTITLES="captions",CODECS="avc1.64001f,mp4a.40.2"
            https://media.example.org/high/index.m3u8?temporaryToken=fixture
        """.trimIndent()))!!
        assertEquals("https://media.example.org/high/index.m3u8?temporaryToken=fixture", manifest.video)
        assertEquals(listOf("../audio/default.m3u8", "audio/second.m3u8"), manifest.audio.map { it.uri })
        assertEquals(listOf("captions/en.m3u8"), manifest.subtitles.map { it.uri })
        assertTrue(manifest.audio.first().default)
        assertEquals("ja", manifest.audio.last().language)
        assertEquals(
            listOf(
                "#EXTM3U", "#EXT-X-VERSION:4",
                """#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Default, English",DEFAULT=YES,AUTOSELECT=YES,LANGUAGE="en",URI="audio-1.m3u8"""",
                """#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Second",DEFAULT=NO,AUTOSELECT=YES,LANGUAGE="ja",CHANNELS="2",URI="audio-2.m3u8"""",
                """#EXT-X-STREAM-INF:BANDWIDTH=1100000,CODECS="avc1.64001f,mp4a.40.2",AUDIO="audio"""", "video.m3u8",
            ),
            HlsManifest.read(manifest.localPlaylist()),
        )
    }

    @Test
    fun encryptedSegmentsAndFragmentMapsBecomeLocalFullFiles() {
        val manifest = media("""
            #EXT-X-VERSION:7
            #EXT-X-MEDIA-SEQUENCE:24
            #EXT-X-MAP:URI="segments.fmp4",BYTERANGE="512@0"
            #EXT-X-KEY:METHOD=AES-128,URI="https://media.example.org/key?fixture",IV=0x18
            #EXTINF:2.500,video title
            #EXT-X-BYTERANGE:500@512
            segments.fmp4
            #EXTINF:2.500,
            #EXT-X-BYTERANGE:400
            segments.fmp4
            #EXT-X-DISCONTINUITY
            #EXT-X-KEY:METHOD=NONE
            #EXTINF:3,
            segments-final.m4s
            #EXT-X-ENDLIST
        """.trimIndent())
        assertEquals(8000L, manifest.durationMs)
        val references = manifest.entries.mapNotNull { it.part }
        assertEquals(listOf("mp4", "key", "m4s", "m4s", "m4s"), references.map { it.extension })
        assertEquals(listOf(HlsRange(0, 512), null, HlsRange(512, 500), HlsRange(1012, 400), null), references.map { it.range })
        assertTrue(references[0].range!!.matches("bytes 0-511/1400"))
        assertFalse(references[0].range!!.matches("bytes 1-512/1400"))
        assertFalse(references[0].range!!.matches("bytes 0-511/500"))
        val output = manifest.entries.joinToString("\n") { it.line }
        assertFalse(output.contains("https://"))
        assertFalse(output.contains("BYTERANGE"))
        assertFalse(output.contains("video title"))
        assertTrue(output.contains("#EXT-X-MEDIA-SEQUENCE:24"))
        assertTrue(output.contains("#EXT-X-DISCONTINUITY"))
        assertTrue(output.contains("""#EXT-X-KEY:METHOD=AES-128,URI="@FILE@",IV=0x18"""))
        assertTrue(output.contains("#EXT-X-ENDLIST"))
    }

    @Test
    fun rejectsUnfinishedUnclearAndUnsupportedMedia() {
        for (input in listOf(
            "#EXTINF:2,\n0.ts",
            "#EXT-X-KEY:METHOD=SAMPLE-AES,URI=\"https://media.example.org/key\"\n#EXTINF:2,\n0.ts\n#EXT-X-ENDLIST",
            "#EXT-X-MAP:URI=\"map.mp4\",EXTERNAL=\"https://elsewhere.example.org/\"\n#EXTINF:2,\n0.ts\n#EXT-X-ENDLIST",
            "#EXT-X-PART:URI=\"part.m4s\"\n#EXTINF:2,\n0.ts\n#EXT-X-ENDLIST",
            "#EXTINF:2,\n#EXT-X-BYTERANGE:2048\n0.ts\n#EXT-X-ENDLIST",
            "#EXTINF:2,\n0.ts\n#EXTINF:2,\n#EXT-X-ENDLIST",
            "#EXT-X-KEY:METHOD=NONE,URI=\"other\"\n#EXTINF:2,\n0.ts\n#EXT-X-ENDLIST",
        )) {
            try {
                media(input)
                fail("Accepted unsupported HLS data")
            } catch (e: HlsTransferFailure) {
                assertEquals("unsupported", e.reason)
            }
        }
    }

    @Test
    fun refusesLocalAndCredentialedRemoteAddresses() {
        assertNull(hlsHttps("https://localhost/stream.m3u8"))
        assertNull(hlsHttps("https://10.0.2.2/stream.m3u8"))
        assertNull(hlsHttps("https://[::1]/stream.m3u8"))
        assertNull(hlsHttps("https://user@example.org/stream.m3u8"))
        assertNull(hlsHttps("https://example.local/stream.m3u8"))
        assertNull(hlsHttps("http://example.org/stream.m3u8"))
        assertTrue(hlsHttps("https://media.example.org/stream.m3u8?fixture=true") != null)
    }

    @Test
    fun scopedDownloadProxyAcceptsOnlyCredentialFreeHttpAndDefersDns() {
        val proxy = checkNotNull(androidVideoProxy("http://proxy.example.org:7897"))
        assertEquals(Proxy.Type.HTTP, proxy.type())
        val address = proxy.address() as InetSocketAddress
        assertEquals("proxy.example.org", address.hostString)
        assertEquals(7897, address.port)
        assertTrue(address.isUnresolved)
        val loopback = checkNotNull(androidVideoProxy("http://[::1]:8080"))
        assertEquals("::1", (loopback.address() as InetSocketAddress).hostString)
        for (bad in listOf("socks5://proxy.example.org:1080", "https://proxy.example.org:443",
            "http://user:pass@proxy.example.org:7897", "http://proxy.example.org:7897/path",
            "http://proxy.example.org:7897?x=1", "http://proxy.example.org:7897#x",
            "http://proxy.example.org:0", "http://proxy.example.org:65536")) {
            assertNull(androidVideoProxy(bad))
        }
    }

    @Test
    fun captionTimelineDeduplicatesSpanningCues() {
        val caption = HlsWebVtt(10_000)
        caption.add("WEBVTT\n\n00:01.500 --> 00:03.000\nAcross segments\n", 0, 2_000)
        caption.add("WEBVTT\n\n00:01.500 --> 00:03.000\nAcross segments\n\n00:03.500 --> 00:04.000\nMore\n", 2_000, 4_000)
        val vtt = caption.file()
        assertEquals(1, Regex("Across segments").findAll(vtt).count())
        assertTrue(vtt.contains("00:00:03.500 --> 00:00:04.000"))
    }

    @Test
    fun captionTimelineRejectsUnanchoredOrSegmentRelativeTimes() {
        for (fixture in listOf(
            "WEBVTT\nX-TIMESTAMP-MAP=LOCAL:00:00:00.000,MPEGTS:900000\n\n00:00.500 --> 00:01.000\nCue",
            "WEBVTT\n\n00:00.500 --> 00:01.000\nCue",
        )) {
            try {
                HlsWebVtt(10_000).add(fixture, 2_000, 4_000)
                fail("Accepted unanchored caption timeline")
            } catch (e: HlsTransferFailure) {
                assertEquals("unsupported", e.reason)
            }
        }
    }

    private fun media(input: String) =
        HlsManifest.media(HlsManifest.read("#EXTM3U\n#EXT-X-TARGETDURATION:8\n$input"))
}
