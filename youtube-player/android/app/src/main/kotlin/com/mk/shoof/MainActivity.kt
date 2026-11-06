package com.mk.shoof

import android.content.ComponentName
import android.content.ContentValues
import android.content.Intent
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.view.WindowManager
import androidx.core.content.ContextCompat
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.MergingMediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private var controllerFuture: ListenableFuture<MediaController>? = null
    private var producer: TextureRegistry.SurfaceProducer? = null
    private var lastError: String? = null
    private var pendingLink: String? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    private val playerListener = object : Player.Listener {
        override fun onVideoSizeChanged(videoSize: VideoSize) {
            if (videoSize.width > 0 && videoSize.height > 0) {
                producer?.setSize(videoSize.width, videoSize.height)
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            lastError = error.errorCodeName + ": " + (error.message ?: "")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingLink = linkFrom(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val link = linkFrom(intent) ?: return
        if (::channel.isInitialized) channel.invokeMethod("link", link) else pendingLink = link
    }

    private fun linkFrom(intent: Intent?): String? {
        if (intent == null) return null
        return when (intent.action) {
            Intent.ACTION_SEND -> intent.getStringExtra(Intent.EXTRA_TEXT)
            Intent.ACTION_VIEW -> intent.dataString
            else -> null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shoof/native")
        val p = flutterEngine.renderer.createSurfaceProducer()
        producer = p
        p.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
            override fun onSurfaceAvailable() {
                PlaybackService.player?.setVideoSurface(p.surface)
            }

            override fun onSurfaceCleanup() {
                PlaybackService.player?.clearVideoSurface()
            }
        })
        channel.setMethodCallHandler { call, result ->
            try {
                handle(call, result)
            } catch (e: Exception) {
                result.error("native", e.message, null)
            }
        }
    }

    private fun attach() {
        val pl = PlaybackService.player ?: return
        pl.removeListener(playerListener)
        pl.addListener(playerListener)
        producer?.let { pl.setVideoSurface(it.surface) }
    }

    private fun connect(done: () -> Unit) {
        if (PlaybackService.player != null && controllerFuture != null) {
            attach(); done(); return
        }
        val token = SessionToken(this, ComponentName(this, PlaybackService::class.java))
        val f = MediaController.Builder(this, token).buildAsync()
        controllerFuture = f
        f.addListener({
            attach()
            done()
        }, ContextCompat.getMainExecutor(this))
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val player = PlaybackService.player
        when (call.method) {
            "init" -> connect { result.success(producer?.id() ?: -1L) }
            "takeLink" -> {
                result.success(pendingLink); pendingLink = null
            }
            "open" -> connect {
                open(call)
                result.success(true)
            }
            "play" -> { player?.play(); result.success(null) }
            "pause" -> { player?.pause(); result.success(null) }
            "stop" -> { player?.stop(); player?.clearMediaItems(); result.success(null) }
            "seek" -> {
                player?.seekTo((call.argument<Number>("ms") ?: 0).toLong()); result.success(null)
            }
            "speed" -> {
                player?.playbackParameters =
                    PlaybackParameters((call.argument<Number>("v") ?: 1.0).toFloat())
                result.success(null)
            }
            "state" -> {
                if (player == null) {
                    result.success(mapOf("ready" to false))
                } else {
                    result.success(
                        mapOf(
                            "ready" to true,
                            "pos" to player.currentPosition,
                            "dur" to player.duration,
                            "buf" to player.bufferedPosition,
                            "playing" to player.isPlaying,
                            "pwr" to player.playWhenReady,
                            "state" to player.playbackState,
                            "w" to player.videoSize.width,
                            "h" to player.videoSize.height,
                            "ratio" to player.videoSize.pixelWidthHeightRatio.toDouble(),
                            "err" to lastError,
                        )
                    )
                }
            }
            "keepOn" -> {
                if (call.argument<Boolean>("v") == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }
            "share" -> {
                val send = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, call.argument<String>("text"))
                }
                startActivity(Intent.createChooser(send, null))
                result.success(null)
            }
            "mux" -> runIo(result) {
                mux(call.argument("video")!!, call.argument("audio")!!, call.argument("out")!!)
                true
            }
            "save" -> runIo(result) {
                save(
                    call.argument("path")!!, call.argument("name")!!,
                    call.argument("mime")!!, call.argument<Boolean>("audio") == true,
                )
            }
            "delete" -> runIo(result) {
                val u = call.argument<String>("uri")!!
                if (u.startsWith("content://")) {
                    contentResolver.delete(Uri.parse(u), null, null) > 0
                } else {
                    File(Uri.parse(u).path ?: u).delete()
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun runIo(result: MethodChannel.Result, block: () -> Any?) {
        io.execute {
            try {
                val v = block()
                main.post { result.success(v) }
            } catch (e: Exception) {
                main.post { result.error("io", e.message, null) }
            }
        }
    }

    private fun open(call: MethodCall) {
        val player = PlaybackService.player ?: return
        lastError = null
        val videoUrl = call.argument<String>("video")
        val audioUrl = call.argument<String>("audio")
        val ua = call.argument<String>("ua")
        val start = (call.argument<Number>("start") ?: 0).toLong()
        val meta = MediaMetadata.Builder()
            .setTitle(call.argument<String>("title"))
            .setArtist(call.argument<String>("artist"))
            .apply { call.argument<String>("art")?.let { setArtworkUri(Uri.parse(it)) } }
            .build()
        val http = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(15_000)
            .setReadTimeoutMs(20_000)
            .apply { if (ua != null) setUserAgent(ua) }
        val factory = DefaultDataSource.Factory(this, http)
        val pf = ProgressiveMediaSource.Factory(factory)
        val sources = mutableListOf<MediaSource>()
        val mainUrl = videoUrl ?: audioUrl ?: return
        sources.add(
            pf.createMediaSource(
                MediaItem.Builder().setUri(mainUrl).setMediaId(mainUrl).setMediaMetadata(meta).build()
            )
        )
        if (videoUrl != null && audioUrl != null) {
            sources.add(pf.createMediaSource(MediaItem.fromUri(audioUrl)))
        }
        val source = if (sources.size == 1) sources[0]
        else MergingMediaSource(true, true, *sources.toTypedArray())
        player.setMediaSource(source, start)
        player.prepare()
        player.play()
    }

    /** Joins a video-only and an audio-only file into one file without re-encoding. */
    private fun mux(videoPath: String, audioPath: String, outPath: String) {
        val webm = outPath.endsWith(".webm")
        val muxer = MediaMuxer(
            outPath,
            if (webm) MediaMuxer.OutputFormat.MUXER_OUTPUT_WEBM else MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4,
        )
        val inputs = listOf(videoPath to "video/", audioPath to "audio/")
        val extractors = mutableListOf<Pair<MediaExtractor, Int>>()
        for ((path, prefix) in inputs) {
            val ex = MediaExtractor()
            ex.setDataSource(path)
            var track = -1
            for (i in 0 until ex.trackCount) {
                val mime = ex.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith(prefix)) { track = i; break }
            }
            if (track < 0) throw IllegalStateException("no $prefix track")
            ex.selectTrack(track)
            val out = muxer.addTrack(ex.getTrackFormat(track))
            extractors.add(ex to out)
        }
        muxer.start()
        val buffer = ByteBuffer.allocate(4 * 1024 * 1024)
        val info = MediaCodec.BufferInfo()
        for ((ex, out) in extractors) {
            while (true) {
                info.offset = 0
                info.size = ex.readSampleData(buffer, 0)
                if (info.size < 0) break
                info.presentationTimeUs = ex.sampleTime
                info.flags = if ((ex.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC) != 0)
                    MediaCodec.BUFFER_FLAG_KEY_FRAME else 0
                muxer.writeSampleData(out, buffer, info)
                ex.advance()
            }
            ex.release()
        }
        muxer.stop()
        muxer.release()
    }

    /** Copies a finished download into the shared Movies/Music folder and returns its uri. */
    private fun save(path: String, name: String, mime: String, audio: Boolean): String {
        val src = File(path)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val collection = if (audio) MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            else MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    (if (audio) Environment.DIRECTORY_MUSIC else Environment.DIRECTORY_MOVIES) + "/Shoof"
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(collection, values)
                ?: throw IllegalStateException("insert failed")
            contentResolver.openOutputStream(uri)!!.use { out ->
                src.inputStream().use { it.copyTo(out, 1 shl 16) }
            }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            src.delete()
            return uri.toString()
        }
        val dir = File(
            getExternalFilesDir(if (audio) Environment.DIRECTORY_MUSIC else Environment.DIRECTORY_MOVIES),
            "Shoof"
        )
        dir.mkdirs()
        val dest = File(dir, name)
        src.copyTo(dest, overwrite = true)
        src.delete()
        return Uri.fromFile(dest).toString()
    }

    override fun onDestroy() {
        PlaybackService.player?.removeListener(playerListener)
        controllerFuture?.let { MediaController.releaseFuture(it) }
        controllerFuture = null
        super.onDestroy()
    }
}
