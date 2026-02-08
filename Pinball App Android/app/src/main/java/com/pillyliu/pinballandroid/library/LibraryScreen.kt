package com.pillyliu.pinballandroid.library

import android.annotation.SuppressLint
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Bundle
import android.os.Parcel
import android.view.MotionEvent
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebViewClient
import android.webkit.WebSettings
import android.webkit.WebView
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalViewConfiguration
import coil.compose.AsyncImage
import coil.request.ImageRequest
import coil.size.Size
import com.halilibo.richtext.markdown.Markdown
import com.halilibo.richtext.ui.RichTextStyle
import com.halilibo.richtext.ui.string.RichTextStringStyle
import com.halilibo.richtext.ui.material3.Material3RichText
import com.pillyliu.pinballandroid.data.PinballDataCache
import com.pillyliu.pinballandroid.data.downloadTextAllowMissing
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.Border
import com.pillyliu.pinballandroid.ui.CardBg
import com.pillyliu.pinballandroid.ui.CardContainer
import com.pillyliu.pinballandroid.ui.EmptyLabel
import com.pillyliu.pinballandroid.ui.LocalBottomBarVisible
import com.pillyliu.pinballandroid.ui.SectionTitle
import org.json.JSONArray
import org.json.JSONObject
import org.commonmark.parser.Parser
import org.commonmark.ext.gfm.tables.TablesExtension
import org.commonmark.renderer.html.HtmlRenderer

private const val LIBRARY_URL = "https://pillyliu.com/pinball/data/pinball_library.json"
private val markdownExtensions = listOf(TablesExtension.create())
private val markdownParser: Parser = Parser.builder().extensions(markdownExtensions).build()
private val markdownRenderer: HtmlRenderer = HtmlRenderer.builder().extensions(markdownExtensions).build()
private val bundleParcelSaver = Saver<Bundle, ByteArray>(
    save = { bundle ->
        val parcel = Parcel.obtain()
        try {
            bundle.writeToParcel(parcel, 0)
            parcel.marshall()
        } finally {
            parcel.recycle()
        }
    },
    restore = { bytes ->
        val parcel = Parcel.obtain()
        try {
            parcel.unmarshall(bytes, 0, bytes.size)
            parcel.setDataPosition(0)
            Bundle.CREATOR.createFromParcel(parcel)
        } finally {
            parcel.recycle()
        }
    },
)

private data class Video(val label: String?, val url: String?)
private data class LibraryGroupSection(val groupKey: Int?, val games: List<PinballGame>)
private enum class LibrarySortOption(val label: String) {
    LOCATION("Sort: Location"),
    BANK("Sort: Bank"),
    ALPHABETICAL("Sort: Alphabetical"),
}
private data class PinballGame(
    val group: Int?,
    val pos: Int?,
    val bank: Int?,
    val name: String,
    val manufacturer: String?,
    val year: Int?,
    val slug: String,
    val playfieldImageUrl: String?,
    val playfieldLocal: String?,
    val rulesheetUrl: String?,
    val videos: List<Video>,
)

@Composable
fun LibraryScreen(contentPadding: PaddingValues) {
    val bottomBarVisible = LocalBottomBarVisible.current
    var games by remember { mutableStateOf(emptyList<PinballGame>()) }
    var query by rememberSaveable { mutableStateOf("") }
    var sortOptionName by rememberSaveable { mutableStateOf(LibrarySortOption.LOCATION.name) }
    var selectedBank by rememberSaveable { mutableStateOf<Int?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var routeKind by rememberSaveable { mutableStateOf("list") }
    var routeSlug by rememberSaveable { mutableStateOf<String?>(null) }
    var routeImageUrl by rememberSaveable { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) {
        try {
            val cached = PinballDataCache.passthroughOrCachedText(LIBRARY_URL)
            games = parseGames(JSONArray(cached.text.orEmpty()))
            error = null
        } catch (t: Throwable) {
            error = "Failed to load pinball library: ${t.message}"
        }
    }
    LaunchedEffect(routeKind) {
        if (routeKind != "playfield") {
            bottomBarVisible.value = true
        }
    }

    val routeGame = routeSlug?.let { slug -> games.firstOrNull { it.slug == slug } }

    when (routeKind) {
        "list" -> LibraryList(
            contentPadding = contentPadding,
            games = games,
            query = query,
            sortOptionName = sortOptionName,
            selectedBank = selectedBank,
            error = error,
            onQueryChange = { query = it },
            onSortOptionChange = { sortOptionName = it },
            onBankChange = { selectedBank = it },
            onOpenGame = {
                routeSlug = it.slug
                routeKind = "detail"
            },
        )

        "detail" -> {
            if (routeGame == null) {
                if (games.isEmpty()) {
                    AppScreen(contentPadding) { EmptyLabel("Loading library...") }
                } else {
                    AppScreen(contentPadding) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            EmptyLabel("Game not found.")
                            Button(onClick = {
                                routeKind = "list"
                                routeSlug = null
                                routeImageUrl = null
                            }) {
                                Text("Back to Library")
                            }
                        }
                    }
                }
            } else {
                LibraryDetail(
                    contentPadding = contentPadding,
                    game = routeGame,
                    onBack = {
                        routeKind = "list"
                        routeSlug = null
                        routeImageUrl = null
                    },
                    onOpenRulesheet = { routeKind = "rulesheet" },
                    onOpenPlayfield = { imageUrl ->
                        routeImageUrl = imageUrl
                        routeKind = "playfield"
                    },
                )
            }
        }

        "rulesheet" -> {
            if (routeGame == null) {
                if (games.isEmpty()) {
                    AppScreen(contentPadding) { EmptyLabel("Loading rulesheet...") }
                } else {
                    AppScreen(contentPadding) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            EmptyLabel("Rulesheet game not found.")
                            Button(onClick = {
                                routeKind = "list"
                                routeSlug = null
                                routeImageUrl = null
                            }) {
                                Text("Back to Library")
                            }
                        }
                    }
                }
            } else {
                RulesheetScreen(
                    contentPadding = contentPadding,
                    slug = routeGame.slug,
                    onBack = { routeKind = "detail" },
                )
            }
        }

        "playfield" -> {
            if (routeGame == null) {
                if (games.isEmpty()) {
                    AppScreen(contentPadding) { EmptyLabel("Loading playfield...") }
                } else {
                    AppScreen(contentPadding) {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            EmptyLabel("Playfield game not found.")
                            Button(onClick = {
                                routeKind = "list"
                                routeSlug = null
                                routeImageUrl = null
                            }) {
                                Text("Back to Library")
                            }
                        }
                    }
                }
            } else {
                val imageCandidates = (
                    listOfNotNull(routeImageUrl) +
                        routeGame.fullscreenPlayfieldCandidates()
                    ).filter { it.isNotBlank() }
                    .distinct()
                PlayfieldScreen(
                    contentPadding = contentPadding,
                    title = routeGame.name,
                    imageUrls = imageCandidates,
                    onBack = { routeKind = "detail" },
                )
            }
        }

        else -> {
            LibraryList(
                contentPadding = contentPadding,
                games = games,
                query = query,
                sortOptionName = sortOptionName,
                selectedBank = selectedBank,
                error = error,
                onQueryChange = { query = it },
                onSortOptionChange = { sortOptionName = it },
                onBankChange = { selectedBank = it },
                onOpenGame = {
                    routeSlug = it.slug
                    routeKind = "detail"
                },
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LibraryList(
    contentPadding: PaddingValues,
    games: List<PinballGame>,
    query: String,
    sortOptionName: String,
    selectedBank: Int?,
    error: String?,
    onQueryChange: (String) -> Unit,
    onSortOptionChange: (String) -> Unit,
    onBankChange: (Int?) -> Unit,
    onOpenGame: (PinballGame) -> Unit,
) {
    val sortOption = remember(sortOptionName) {
        LibrarySortOption.entries.firstOrNull { it.name == sortOptionName } ?: LibrarySortOption.LOCATION
    }
    val bankOptions = games.mapNotNull { it.bank }.toSet().sorted()
    val filtered = games.filter { game ->
        val q = query.trim().lowercase()
        val queryMatch = if (q.isBlank()) true else {
            "${game.name} ${game.manufacturer.orEmpty()} ${game.year?.toString().orEmpty()}".lowercase().contains(q)
        }
        val bankMatch = selectedBank == null || game.bank == selectedBank
        queryMatch && bankMatch
    }
    val sortedGames = remember(filtered, sortOption) { sortLibraryGames(filtered, sortOption) }
    val showGroupedView = selectedBank == null && (sortOption == LibrarySortOption.LOCATION || sortOption == LibrarySortOption.BANK)
    val groupedSections = remember(sortedGames, sortOption) {
        when (sortOption) {
            LibrarySortOption.LOCATION -> buildSections(sortedGames) { it.group }
            LibrarySortOption.BANK -> buildSections(sortedGames) { it.bank }
            LibrarySortOption.ALPHABETICAL -> emptyList()
        }
    }

    AppScreen(contentPadding) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            CardContainer {
                OutlinedTextField(
                    value = query,
                    onValueChange = onQueryChange,
                    label = { Text("Search games...", fontSize = 12.sp) },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 44.dp),
                    shape = RoundedCornerShape(14.dp),
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None),
                    textStyle = TextStyle(color = Color.White, fontSize = 13.sp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = Color.White,
                        unfocusedTextColor = Color.White,
                        focusedLabelColor = Color.White,
                        unfocusedLabelColor = Color(0xFFCECECE),
                        cursorColor = Color.White,
                    ),
                )

                BoxWithConstraints {
                    val menuWidth = (maxWidth - 8.dp) / 2
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        CompactLibraryFilterMenu(
                            selected = sortOption.label,
                            options = LibrarySortOption.entries.map { it.label },
                            modifier = Modifier.width(menuWidth),
                        ) { selected ->
                            val option = LibrarySortOption.entries.firstOrNull { it.label == selected } ?: LibrarySortOption.LOCATION
                            onSortOptionChange(option.name)
                        }

                        CompactLibraryFilterMenu(
                            selected = selectedBank?.let { "Bank $it" } ?: "All banks",
                            options = listOf("All banks") + bankOptions.map { "Bank $it" },
                            modifier = Modifier.width(menuWidth),
                        ) { selected ->
                            val bank = selected.removePrefix("Bank ").trim().toIntOrNull()
                            onBankChange(bank)
                        }
                    }
                }
            }

            error?.let { Text(it, color = Color.Red) }

            if (sortedGames.isEmpty()) {
                EmptyLabel(if (games.isEmpty()) "Loading library..." else "No data loaded.")
            } else {
                Column(
                    modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    if (showGroupedView) {
                        groupedSections.forEachIndexed { idx, section ->
                            if (idx > 0) {
                                HorizontalDivider(color = Color.White.copy(alpha = 0.7f), thickness = 1.dp)
                            }
                            LibrarySectionGrid(games = section.games, onOpenGame = onOpenGame)
                        }
                    } else {
                        LibrarySectionGrid(games = sortedGames, onOpenGame = onOpenGame)
                    }
                }
            }
        }
    }
}

@Composable
private fun CompactLibraryFilterMenu(
    selected: String,
    options: List<String>,
    modifier: Modifier = Modifier,
    onSelect: (String) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Column(modifier = modifier) {
        OutlinedButton(
            onClick = { expanded = true },
            modifier = Modifier.fillMaxWidth().defaultMinSize(minHeight = 34.dp),
            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 3.dp),
            shape = RoundedCornerShape(10.dp),
        ) {
            Text(selected, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option, fontSize = 12.sp) },
                    onClick = {
                        expanded = false
                        onSelect(option)
                    },
                )
            }
        }
    }
}

@Composable
private fun LibrarySectionGrid(games: List<PinballGame>, onOpenGame: (PinballGame) -> Unit) {
    BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
        val tileWidth = (maxWidth - 12.dp) / 2
        val rows = games.chunked(2)
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            rows.forEach { rowGames ->
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    rowGames.forEach { game ->
                        Box(modifier = Modifier.width(tileWidth)) {
                            LibraryGameCard(game = game, onClick = { onOpenGame(game) })
                        }
                    }
                    if (rowGames.size == 1) {
                        Spacer(Modifier.width(tileWidth))
                    }
                }
            }
        }
    }
}

private fun buildSections(
    filtered: List<PinballGame>,
    keySelector: (PinballGame) -> Int?,
): List<LibraryGroupSection> {
    val out = mutableListOf<LibraryGroupSection>()
    filtered.forEach { game ->
        val key = keySelector(game)
        if (out.isNotEmpty() && out.last().groupKey == key) {
            val merged = out.last().games + game
            out[out.lastIndex] = LibraryGroupSection(groupKey = key, games = merged)
        } else {
            out += LibraryGroupSection(groupKey = key, games = listOf(game))
        }
    }
    return out
}

private fun sortLibraryGames(games: List<PinballGame>, option: LibrarySortOption): List<PinballGame> {
    return when (option) {
        LibrarySortOption.LOCATION -> games.sortedWith(
            compareBy<PinballGame> { it.group ?: Int.MAX_VALUE }
                .thenBy { it.pos ?: Int.MAX_VALUE }
                .thenBy { it.name.lowercase() },
        )
        LibrarySortOption.BANK -> games.sortedWith(
            compareBy<PinballGame> { it.bank ?: Int.MAX_VALUE }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.pos ?: Int.MAX_VALUE }
                .thenBy { it.name.lowercase() },
        )
        LibrarySortOption.ALPHABETICAL -> games.sortedWith(
            compareBy<PinballGame> { it.name.lowercase() }
                .thenBy { it.group ?: Int.MAX_VALUE }
                .thenBy { it.pos ?: Int.MAX_VALUE },
        )
    }
}

@Composable
private fun LibraryGameCard(game: PinballGame, onClick: () -> Unit) {
    Column(
        modifier = Modifier
            .background(Color(0xFF171717), RoundedCornerShape(12.dp))
            .border(1.dp, Color(0xFF343434), RoundedCornerShape(12.dp))
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
    ) {
        AsyncImage(
            model = game.libraryPlayfieldCandidate(),
            contentDescription = game.name,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 96.dp)
                .aspectRatio(16f / 9f),
            contentScale = ContentScale.FillWidth,
        )

        Column(modifier = Modifier.padding(horizontal = 10.dp, vertical = 7.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                game.name,
                color = Color.White,
                maxLines = 2,
                minLines = 2,
                overflow = TextOverflow.Ellipsis,
                lineHeight = 16.sp,
            )
            Text(game.manufacturerYearLine(), color = Color(0xFFB0B0B0), maxLines = 1, fontSize = 12.sp, lineHeight = 14.sp)
            Text(game.locationBankLine(), color = Color(0xFFC0C0C0), maxLines = 1, fontSize = 12.sp, lineHeight = 14.sp)
        }
    }
}

@Composable
private fun LibraryDetail(
    contentPadding: PaddingValues,
    game: PinballGame,
    onBack: () -> Unit,
    onOpenRulesheet: () -> Unit,
    onOpenPlayfield: (String) -> Unit,
) {
    val uriHandler = LocalUriHandler.current
    val detailScroll = rememberSaveable(game.slug, saver = androidx.compose.foundation.ScrollState.Saver) {
        androidx.compose.foundation.ScrollState(0)
    }
    var markdown by rememberSaveable(game.slug) { mutableStateOf<String?>(null) }
    var infoStatus by rememberSaveable(game.slug) { mutableStateOf("loading") }
    var activeVideoId by rememberSaveable(game.slug) {
        mutableStateOf<String?>(null)
    }

    LaunchedEffect(game.slug) {
        if (infoStatus == "loaded" || infoStatus == "missing") return@LaunchedEffect
        val (code, text) = downloadTextAllowMissing("https://pillyliu.com/pinball/gameinfo/${game.slug}.md")
        when {
            code == 404 -> infoStatus = "missing"
            code in 200..299 && !text.isNullOrBlank() -> {
                markdown = text
                infoStatus = "loaded"
            }
            else -> infoStatus = "error"
        }
    }

    AppScreen(contentPadding) {
        Column(
            modifier = Modifier.fillMaxSize().verticalScroll(detailScroll),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Button(onClick = onBack) { Text("Back") }
                Spacer(Modifier.width(10.dp))
                Text(game.name, color = Color.White, fontWeight = FontWeight.SemiBold)
            }

            CardContainer {
                FallbackAsyncImage(
                    urls = game.gameInlinePlayfieldCandidates(),
                    contentDescription = game.name,
                    modifier = Modifier.fillMaxWidth().aspectRatio(16f / 9f),
                    contentScale = ContentScale.FillWidth,
                )
                Text(game.metaLine(), color = Color(0xFFB7B7B7))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = onOpenRulesheet) { Text("Rulesheet") }
                    game.fullscreenPlayfieldCandidates().firstOrNull()?.let { url ->
                        OutlinedButton(onClick = { onOpenPlayfield(url) }) { Text("Playfield") }
                    }
                }
            }

            CardContainer {
                SectionTitle("Videos")
                val playableVideos = game.videos.mapNotNull { v -> youtubeId(v.url)?.let { it to (v.label ?: "Video") } }
                if (playableVideos.isEmpty()) {
                    Text("No videos listed.", color = Color(0xFFBDBDBD))
                } else {
                    activeVideoId?.let { id ->
                        EmbeddedYouTubeView(videoId = id)
                    } ?: Text("Tap a video below to load player.", color = Color(0xFFBDBDBD))
                    BoxWithConstraints {
                        val tileWidth = (maxWidth - 10.dp) / 2
                        val rows = playableVideos.chunked(2)
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            rows.forEach { rowItems ->
                                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    rowItems.forEach { (id, label) ->
                                        VideoTile(
                                            videoId = id,
                                            label = label,
                                            selected = activeVideoId == id,
                                            width = tileWidth,
                                            onSelect = { activeVideoId = id },
                                        )
                                    }
                                    if (rowItems.size == 1) {
                                        Spacer(Modifier.width(tileWidth))
                                    }
                                }
                            }
                        }
                    }
                }
            }

            CardContainer {
                SectionTitle("Game Info")
                when (infoStatus) {
                    "loading" -> Text("Loading...", color = Color(0xFFD0D0D0))
                    "missing" -> Text("No game info yet.", color = Color(0xFFD0D0D0))
                    "error" -> Text("Could not load game info.", color = Color(0xFFD0D0D0))
                    else -> CompositionLocalProvider(LocalContentColor provides Color.White) {
                        val gameInfoStyle = remember {
                            RichTextStyle.Default.copy(
                                stringStyle = RichTextStringStyle.Default.copy(
                                    linkStyle = SpanStyle(color = Color(0xFF8EC5FF)),
                                ),
                            )
                        }
                        Material3RichText(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(bottom = 20.dp),
                            style = gameInfoStyle,
                        ) {
                            Markdown(markdown.orEmpty())
                        }
                    }
                }
            }

            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.horizontalScroll(rememberScrollState()),
            ) {
                game.rulesheetUrl?.let {
                    OutlinedButton(
                        onClick = { uriHandler.openUri(it) },
                        modifier = Modifier.defaultMinSize(minHeight = 32.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                        colors = ButtonDefaults.outlinedButtonColors(
                            containerColor = CardBg,
                            contentColor = Color.White,
                        ),
                        border = androidx.compose.foundation.BorderStroke(1.dp, Border),
                    ) {
                        Text("Rulesheet (source)", fontSize = 12.sp)
                    }
                }
                game.playfieldImageUrl?.let {
                    OutlinedButton(
                        onClick = { uriHandler.openUri(it) },
                        modifier = Modifier.defaultMinSize(minHeight = 32.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp, vertical = 4.dp),
                        colors = ButtonDefaults.outlinedButtonColors(
                            containerColor = CardBg,
                            contentColor = Color.White,
                        ),
                        border = androidx.compose.foundation.BorderStroke(1.dp, Border),
                    ) {
                        Text("Playfield (source)", fontSize = 12.sp)
                    }
                }
            }
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun EmbeddedYouTubeView(videoId: String) {
    var loadedVideoId by rememberSaveable { mutableStateOf<String?>(null) }
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
    val landscapeByAspect = configuration.screenWidthDp.dp * (9f / 16f)
    val landscapeMax = configuration.screenHeightDp.dp * 0.78f
    val playerHeight = if (isLandscape) {
        minOf(landscapeByAspect, landscapeMax).coerceAtLeast(300.dp)
    } else {
        220.dp
    }

    AndroidView(
        modifier = Modifier.fillMaxWidth().height(playerHeight),
        factory = { context ->
            WebView(context).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.mediaPlaybackRequiresUserGesture = false
                settings.loadsImagesAutomatically = true
                settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                settings.useWideViewPort = false
                settings.loadWithOverviewMode = false
                settings.userAgentString =
                    "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 " +
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
                setBackgroundColor(android.graphics.Color.BLACK)
                webChromeClient = WebChromeClient()
                webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                        val url = request?.url?.toString() ?: return false
                        return openYoutubeInApp(context, url, fallbackVideoId = videoId)
                    }

                    override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
                        val link = url ?: return false
                        return openYoutubeInApp(context, link, fallbackVideoId = videoId)
                    }
                }
            }
        },
        update = { webView ->
            if (loadedVideoId != videoId) {
                loadedVideoId = videoId
                webView.loadUrl("https://m.youtube.com/watch?v=$videoId&app=m")
            }
        },
        onRelease = { webView ->
            webView.stopLoading()
            webView.destroy()
        },
    )
}

@Composable
private fun RulesheetScreen(contentPadding: PaddingValues, slug: String, onBack: () -> Unit) {
    var status by rememberSaveable(slug) { mutableStateOf("loading") }
    var markdown by rememberSaveable(slug) { mutableStateOf("") }

    LaunchedEffect(slug) {
        if (status == "loaded" || status == "missing") return@LaunchedEffect
        val (code, text) = downloadTextAllowMissing("https://pillyliu.com/pinball/rulesheets/$slug.md")
        when {
            code == 404 -> status = "missing"
            code in 200..299 && !text.isNullOrBlank() -> {
                status = "loaded"
                markdown = normalizeRulesheet(text)
            }
            else -> status = "error"
        }
    }

    AppScreen(contentPadding) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxSize()) {
            Button(onClick = onBack) { Text("Back") }
            when (status) {
                "loading" -> EmptyLabel("Loading rulesheet...")
                "missing" -> EmptyLabel("Rulesheet not available.")
                "error" -> EmptyLabel("Could not load rulesheet.")
                else -> Box(modifier = Modifier.fillMaxSize()) {
                    MarkdownWebView(markdown, Modifier.fillMaxSize(), stateKey = "rulesheet-$slug")
                }
            }
        }
    }
}

@Composable
private fun PlayfieldScreen(contentPadding: PaddingValues, title: String, imageUrls: List<String>, onBack: () -> Unit) {
    val bottomBarVisible = LocalBottomBarVisible.current
    var chromeVisible by rememberSaveable(title) { mutableStateOf(false) }

    LaunchedEffect(chromeVisible) {
        bottomBarVisible.value = chromeVisible
    }
    DisposableEffect(Unit) {
        onDispose { bottomBarVisible.value = true }
    }

    Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
        ZoomablePlayfieldImage(
            imageUrls = imageUrls,
            title = title,
            modifier = Modifier.fillMaxSize(),
            onTap = { chromeVisible = !chromeVisible },
        )

        if (chromeVisible) {
            Row(
                modifier = Modifier
                    .padding(contentPadding)
                    .padding(start = 14.dp, end = 14.dp, top = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Button(onClick = onBack) { Text("Back") }
                Spacer(Modifier.width(10.dp))
                Text(title, color = Color.White, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun ZoomablePlayfieldImage(
    imageUrls: List<String>,
    title: String,
    modifier: Modifier = Modifier,
    onTap: () -> Unit = {},
) {
    val context = LocalContext.current
    val candidates = imageUrls.filter { it.isNotBlank() }.distinct()
    var activeImageIndex by remember(candidates) { mutableStateOf(0) }
    var scale by remember { mutableStateOf(1f) }
    var offsetX by remember { mutableStateOf(0f) }
    var offsetY by remember { mutableStateOf(0f) }
    val touchSlop = LocalViewConfiguration.current.touchSlop

    Box(
        modifier = modifier
            .clipToBounds()
            .pointerInput(touchSlop) {
                awaitEachGesture {
                    var moved = false
                    var multiTouch = false
                    var transformed = false
                    var activePointer: androidx.compose.ui.input.pointer.PointerId? = null
                    var accumulatedMove = Offset.Zero

                    do {
                        val event = awaitPointerEvent()
                        val pressedChanges = event.changes.filter { it.pressed }
                        val pointersDown = pressedChanges.size
                        if (pointersDown >= 2) multiTouch = true
                        if (activePointer == null && pressedChanges.isNotEmpty()) {
                            activePointer = pressedChanges.first().id
                        }
                        val tracked = pressedChanges.firstOrNull { it.id == activePointer } ?: pressedChanges.firstOrNull()
                        if (tracked != null) {
                            accumulatedMove += tracked.position - tracked.previousPosition
                            if (accumulatedMove.getDistance() > touchSlop) moved = true
                        }

                        if (pointersDown >= 2 || scale > 1f) {
                            val zoom = event.calculateZoom()
                            val pan = event.calculatePan()
                            if (pointersDown >= 2 || kotlin.math.abs(zoom - 1f) > 0.01f || pan.getDistance() > 0f) {
                                transformed = true
                            }
                            scale = (scale * zoom).coerceIn(1f, 6f)
                            if (scale > 1f) {
                                offsetX += pan.x
                                offsetY += pan.y
                            } else {
                                offsetX = 0f
                                offsetY = 0f
                            }
                        }
                    } while (event.changes.any { it.pressed })

                    if (!multiTouch && !moved && !transformed) {
                        onTap()
                    }
                }
            },
    ) {
        val activeUrl = candidates.getOrNull(activeImageIndex)
        val cachedModel = rememberCachedImageModel(activeUrl)
        AsyncImage(
            model = cachedModel?.let { model ->
                ImageRequest.Builder(context)
                    .data(model)
                    .size(Size.ORIGINAL)
                    .build()
            },
            contentDescription = title,
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                    translationX = offsetX
                    translationY = offsetY
                },
            contentScale = ContentScale.Fit,
            onError = {
                if (activeImageIndex < candidates.lastIndex) {
                    activeImageIndex += 1
                }
            },
        )
    }
}

@Composable
private fun FallbackAsyncImage(
    urls: List<String>,
    contentDescription: String,
    modifier: Modifier,
    contentScale: ContentScale,
) {
    val candidates = urls.filter { it.isNotBlank() }.distinct()
    var activeIndex by remember(candidates) { mutableStateOf(0) }
    val model = rememberCachedImageModel(candidates.getOrNull(activeIndex))
    AsyncImage(
        model = model,
        contentDescription = contentDescription,
        modifier = modifier,
        contentScale = contentScale,
        onError = {
            if (activeIndex < candidates.lastIndex) {
                activeIndex += 1
            }
        },
    )
}

@Composable
private fun rememberCachedImageModel(url: String?): Any? {
    if (url.isNullOrBlank()) return null
    val model by produceState<Any?>(initialValue = url, key1 = url) {
        value = try {
            PinballDataCache.resolveImageModel(url)
        } catch (_: Throwable) {
            url
        }
    }
    return model
}

@Composable
private fun VideoTile(
    videoId: String,
    label: String,
    selected: Boolean,
    width: androidx.compose.ui.unit.Dp,
    onSelect: () -> Unit,
) {
    Column(
        modifier = Modifier
            .width(width)
            .clickable(onClick = onSelect)
            .background(if (selected) Color(0xFF333333) else Color(0xFF1F1F1F), RoundedCornerShape(8.dp))
            .border(1.dp, if (selected) Color(0xFF666666) else Color(0xFF343434), RoundedCornerShape(8.dp))
            .padding(8.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        AsyncImage(
            model = "https://i.ytimg.com/vi/$videoId/hqdefault.jpg",
            contentDescription = label,
            modifier = Modifier.fillMaxWidth().aspectRatio(16f / 9f),
            contentScale = ContentScale.Crop,
        )
        Text(label, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun MarkdownWebView(markdown: String, modifier: Modifier = Modifier, stateKey: String = "default") {
    val webViewState = rememberSaveable(stateKey, saver = bundleParcelSaver) { Bundle() }
    var savedScrollRatio by rememberSaveable(stateKey) { mutableStateOf(0f) }
    var loadedHash by remember(stateKey) { mutableStateOf<Int?>(null) }
    AndroidView(
        modifier = modifier,
        factory = { context ->
            WebView(context).apply {
                setBackgroundColor(android.graphics.Color.BLACK)
                settings.javaScriptEnabled = false
                settings.cacheMode = WebSettings.LOAD_NO_CACHE
                settings.domStorageEnabled = true
                isVerticalScrollBarEnabled = true
                overScrollMode = WebView.OVER_SCROLL_IF_CONTENT_SCROLLS
                setOnTouchListener { view, event ->
                    if (event.action == MotionEvent.ACTION_DOWN || event.action == MotionEvent.ACTION_MOVE) {
                        view.parent?.requestDisallowInterceptTouchEvent(true)
                    }
                    false
                }
                webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView?, url: String?) {
                        super.onPageFinished(view, url)
                        view?.post {
                            view.requestLayout()
                            view.invalidate()
                        }
                    }
                }
                setOnScrollChangeListener { view, _, scrollY, _, _ ->
                    val webView = view as? WebView ?: return@setOnScrollChangeListener
                    val contentPx = (webView.contentHeight * webView.resources.displayMetrics.density).toInt()
                    val maxScroll = (contentPx - view.height).coerceAtLeast(1)
                    savedScrollRatio = (scrollY.toFloat() / maxScroll.toFloat()).coerceIn(0f, 1f)
                }
                if (!webViewState.isEmpty) {
                    restoreState(webViewState)
                    post {
                        val contentPx = (contentHeight * resources.displayMetrics.density).toInt()
                        val maxScroll = (contentPx - height).coerceAtLeast(0)
                        val contextOffset = (24f * resources.displayMetrics.density).toInt()
                        val target = ((savedScrollRatio * maxScroll).toInt() - contextOffset).coerceAtLeast(0)
                        scrollTo(0, target)
                    }
                }
            }
        },
        update = { webView ->
            val newHash = markdown.hashCode()
            if (loadedHash != newHash && webViewState.isEmpty) {
                val renderedHtml = markdownRenderer.render(markdownParser.parse(markdown))
                val html = """
                    <!doctype html>
                    <html>
                    <head>
                        <meta charset=\"utf-8\" />
                        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
                        <style>
                            html, body { margin:0; padding:0; background:#000 !important; color:#fff !important; overflow-x:hidden !important; width:100%; }
                            body { padding:14px; line-height:1.45; font-size:16px; box-sizing:border-box; }
                            *, *:before, *:after { box-sizing:border-box; }
                            * { color:#fff !important; background: transparent !important; }
                            a { color:#a6c8ff !important; }
                            code, pre { background:#111 !important; border-radius:8px; color:#fff !important; }
                            pre { padding:10px; white-space:pre-wrap; overflow-wrap:anywhere; word-break:break-word; }
                            table { border-collapse:collapse; width:100%; max-width:100%; table-layout:fixed; }
                            th, td { border:1px solid #2a2a2a; padding:6px 8px; word-break:break-word; overflow-wrap:anywhere; }
                            img { max-width:100%; height:auto; display:block; }
                        </style>
                    </head>
                    <body>
                        <article id=\"content\">$renderedHtml</article>
                    </body>
                    </html>
                """.trimIndent()
                webView.loadDataWithBaseURL("https://pillyliu.com", html, "text/html", "utf-8", null)
                loadedHash = newHash
                webView.post {
                    val contentPx = (webView.contentHeight * webView.resources.displayMetrics.density).toInt()
                    val maxScroll = (contentPx - webView.height).coerceAtLeast(0)
                    val contextOffset = (24f * webView.resources.displayMetrics.density).toInt()
                    val target = ((savedScrollRatio * maxScroll).toInt() - contextOffset).coerceAtLeast(0)
                    webView.scrollTo(0, target)
                }
            }
        },
        onRelease = { webView ->
            val contentPx = (webView.contentHeight * webView.resources.displayMetrics.density).toInt()
            val maxScroll = (contentPx - webView.height).coerceAtLeast(1)
            savedScrollRatio = (webView.scrollY.toFloat() / maxScroll.toFloat()).coerceIn(0f, 1f)
            val out = Bundle()
            val backStack = webView.saveState(out)
            // Avoid clobbering a previously valid saved state with an empty one.
            if (backStack != null && !out.isEmpty) {
                webViewState.clear()
                webViewState.putAll(out)
            }
        },
    )
}

private fun parseGames(array: JSONArray): List<PinballGame> {
    return (0 until array.length()).mapNotNull { i ->
        val obj = array.optJSONObject(i) ?: return@mapNotNull null
        val name = obj.optString("name")
        val slug = obj.optString("slug")
        if (name.isBlank() || slug.isBlank()) return@mapNotNull null

        PinballGame(
            group = obj.optIntOrNull("group"),
            pos = obj.optIntOrNull("pos"),
            bank = obj.optIntOrNull("bank"),
            name = name,
            manufacturer = obj.optStringOrNull("manufacturer"),
            year = obj.optIntOrNull("year"),
            slug = slug,
            playfieldImageUrl = obj.optStringOrNull("playfieldImageUrl"),
            playfieldLocal = obj.optStringOrNull("playfieldLocal"),
            rulesheetUrl = obj.optStringOrNull("rulesheetUrl"),
            videos = obj.optJSONArray("videos")?.let { vids ->
                (0 until vids.length()).mapNotNull { idx ->
                    vids.optJSONObject(idx)?.let { v -> Video(v.optStringOrNull("label"), v.optStringOrNull("url")) }
                }
            } ?: emptyList(),
        )
    }
}

private fun PinballGame.metaLine(): String {
    val parts = mutableListOf<String>()
    parts += manufacturer ?: "-"
    year?.let { parts += "$it" }
    locationText()?.let { parts += it }
    bank?.takeIf { it > 0 }?.let { parts += "Bank $it" }
    return parts.joinToString(" • ")
}

private fun PinballGame.manufacturerYearLine(): String {
    return if (year != null) "${manufacturer ?: "-"} • $year" else (manufacturer ?: "-")
}

private fun PinballGame.locationBankLine(): String {
    val parts = mutableListOf<String>()
    locationText()?.let { parts += it }
    bank?.takeIf { it > 0 }?.let { parts += "Bank $it" }
    return if (parts.isEmpty()) "-" else parts.joinToString(" • ")
}

private fun PinballGame.locationText(): String? {
    val g = group ?: return null
    val p = pos ?: return null
    val floor = if (g in 1..4) "U" else "D"
    return "$floor:$g:$p"
}

private fun PinballGame.resolve(pathOrUrl: String?): String? {
    pathOrUrl ?: return null
    if (pathOrUrl.startsWith("http://") || pathOrUrl.startsWith("https://")) return pathOrUrl
    return if (pathOrUrl.startsWith("/")) "https://pillyliu.com$pathOrUrl" else "https://pillyliu.com/$pathOrUrl"
}

private fun PinballGame.derivedPlayfield(width: Int): String? {
    val local = playfieldLocal ?: return null
    val path = if (local.startsWith("http://") || local.startsWith("https://")) {
        java.net.URI(local).path ?: return null
    } else {
        local
    }
    val slash = path.lastIndexOf('/')
    if (slash < 0) return null
    return resolve("${path.substring(0, slash)}/${slug}_${width}.webp")
}

private fun PinballGame.libraryPlayfieldCandidate(): String? = derivedPlayfield(700)
private fun PinballGame.gameInlinePlayfieldCandidates(): List<String> =
    listOfNotNull(derivedPlayfield(1400), resolve(playfieldLocal), derivedPlayfield(700))

private fun PinballGame.fullscreenPlayfieldCandidates(): List<String> =
    listOfNotNull(resolve(playfieldLocal), derivedPlayfield(1400), derivedPlayfield(700))

private fun openYoutubeInApp(context: android.content.Context, url: String, fallbackVideoId: String): Boolean {
    return try {
        if (url.startsWith("intent:")) {
            val intent = Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } else {
            val id = youtubeId(url) ?: fallbackVideoId
            val appIntent = Intent(Intent.ACTION_VIEW, Uri.parse("vnd.youtube:$id")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                context.startActivity(appIntent)
            } catch (_: ActivityNotFoundException) {
                val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/watch?v=$id")).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(webIntent)
            }
            true
        }
    } catch (_: Throwable) {
        false
    }
}

private fun youtubeId(raw: String?): String? {
    raw ?: return null
    return try {
        val uri = java.net.URI(raw)
        val host = uri.host?.lowercase() ?: return null
        when {
            host.contains("youtu.be") -> uri.path.removePrefix("/").takeIf { it.isNotBlank() }
            host.contains("youtube.com") -> {
                val queryID = uri.query
                    ?.split("&")
                    ?.mapNotNull {
                        val pair = it.split("=", limit = 2)
                        if (pair.size == 2 && pair[0] == "v") pair[1] else null
                    }
                    ?.firstOrNull()

                queryID
                    ?: uri.path.removePrefix("/shorts/").takeIf { uri.path.startsWith("/shorts/") && it.isNotBlank() }
                    ?: uri.path.removePrefix("/embed/").takeIf { uri.path.startsWith("/embed/") && it.isNotBlank() }
            }
            else -> null
        }
    } catch (_: Throwable) {
        null
    }
}

private fun JSONObject.optIntOrNull(name: String): Int? = if (has(name) && !isNull(name)) optInt(name) else null
private fun JSONObject.optStringOrNull(name: String): String? = optString(name).takeIf { it.isNotBlank() }

private fun normalizeRulesheet(input: String): String {
    var text = input.replace("\r\n", "\n")
    if (text.startsWith("---\n")) {
        val start = 4
        val end = text.indexOf("\n---", start)
        if (end >= 0) {
            val after = text.indexOf('\n', end + 4)
            if (after >= 0 && after + 1 < text.length) {
                text = text.substring(after + 1)
            }
        }
    }
    return text.trim()
}
