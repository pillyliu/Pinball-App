package com.pillyliu.pinprofandroid

import androidx.annotation.DrawableRes
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import com.pillyliu.pinprofandroid.ui.PinballThemeTokens

internal enum class AppIntroProfessorSide {
    Left,
    Right,
}

internal enum class AppIntroCard(
    val title: String?,
    val subtitle: String?,
    val quote: String,
    val highlightedQuotePhrase: String?,
    val accent: Color,
    @get:DrawableRes val artworkResId: Int,
    val artworkAspectRatio: Float,
    val showsProfessorSpotlight: Boolean,
    val professorSide: AppIntroProfessorSide,
) {
    Welcome(
        title = null,
        subtitle = null,
        quote = "Welcome to PinProf, a pinball study app. Go from pinball novice to pinball wizard in no time!",
        highlightedQuotePhrase = "PinProf",
        accent = AppIntroTheme.glow,
        artworkResId = R.drawable.intro_launch_logo,
        artworkAspectRatio = 1f,
        showsProfessorSpotlight = false,
        professorSide = AppIntroProfessorSide.Left,
    ),
    League(
        title = "League",
        subtitle = "Lansing Pinball League stats",
        quote = "Among peers, statistics reveal true standing.",
        highlightedQuotePhrase = null,
        accent = Color(0xFFC3C978),
        artworkResId = R.drawable.intro_league_screenshot,
        artworkAspectRatio = 1206f / 1809f,
        showsProfessorSpotlight = true,
        professorSide = AppIntroProfessorSide.Left,
    ),
    Library(
        title = "Library",
        subtitle = "Rulesheets, playfields, tutorials",
        quote = "Attend closely; mastery follows diligence.",
        highlightedQuotePhrase = null,
        accent = Color(0xFF8FDBC7),
        artworkResId = R.drawable.intro_library_screenshot,
        artworkAspectRatio = 1206f / 1809f,
        showsProfessorSpotlight = true,
        professorSide = AppIntroProfessorSide.Right,
    ),
    Practice(
        title = "Practice",
        subtitle = "Track practice, trends, progress",
        quote = "A careful record reveals true progress.",
        highlightedQuotePhrase = null,
        accent = Color(0xFFFFDB66),
        artworkResId = R.drawable.intro_practice_screenshot,
        artworkAspectRatio = 1206f / 1809f,
        showsProfessorSpotlight = true,
        professorSide = AppIntroProfessorSide.Left,
    ),
    GameRoom(
        title = "GameRoom",
        subtitle = "Organize machines and upkeep",
        quote = "Order and care are marks of excellence.",
        highlightedQuotePhrase = null,
        accent = Color(0xFFF5C75C),
        artworkResId = R.drawable.intro_gameroom_screenshot,
        artworkAspectRatio = 1206f / 1809f,
        showsProfessorSpotlight = true,
        professorSide = AppIntroProfessorSide.Right,
    ),
    Settings(
        title = "Settings",
        subtitle = "Sources, venues, tournaments, data",
        quote = "A well-curated library reflects discernment.",
        highlightedQuotePhrase = null,
        accent = Color(0xFFB8E5C2),
        artworkResId = R.drawable.intro_settings_screenshot,
        artworkAspectRatio = 1206f / 1809f,
        showsProfessorSpotlight = true,
        professorSide = AppIntroProfessorSide.Left,
    ),
}

internal object AppIntroTheme {
    val tint = Color(0xFF1F5742)
    val glow = Color(0xFFA3E0BD)
    val text = Color.White.copy(alpha = 0.96f)
    val secondaryText = Color.White.copy(alpha = 0.84f)
}

internal object AppIntroTypography {
    val title = FontFamily(
        Font(R.font.bodoni_moda_variable, weight = FontWeight.Bold),
    )
    val subtitle = FontFamily(
        Font(R.font.cormorant_garamond_variable, weight = FontWeight.SemiBold),
    )
    val quote = FontFamily(
        Font(
            R.font.libre_baskerville_italic_variable,
            weight = FontWeight.SemiBold,
            style = FontStyle.Italic,
        ),
        Font(
            R.font.libre_baskerville_italic_variable,
            weight = FontWeight.Bold,
            style = FontStyle.Italic,
        ),
    )
}

@Composable
internal fun AppIntroCard.resolvedAccent(): Color {
    return when (this) {
        AppIntroCard.League -> PinballThemeTokens.colors.statsMeanMedian
        else -> accent
    }
}
