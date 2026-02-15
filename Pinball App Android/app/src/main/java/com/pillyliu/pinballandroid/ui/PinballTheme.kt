package com.pillyliu.pinballandroid.ui

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

private val DarkColorScheme = darkColorScheme(
    primary = Color(0xFFC8D9FF),
    onPrimary = Color(0xFF0F1C37),
    primaryContainer = Color(0xFF253355),
    onPrimaryContainer = Color(0xFFDFE7FF),
    secondary = Color(0xFFC6D7F2),
    onSecondary = Color(0xFF102031),
    secondaryContainer = Color(0xFF27384A),
    onSecondaryContainer = Color(0xFFE1EEFF),
    tertiary = Color(0xFFB8E8D0),
    onTertiary = Color(0xFF002117),
    tertiaryContainer = Color(0xFF1F4F3D),
    onTertiaryContainer = Color(0xFFD3FDE4),
    error = Color(0xFFFFB4AB),
    onError = Color(0xFF690005),
    errorContainer = Color(0xFF93000A),
    onErrorContainer = Color(0xFFFFDAD6),
    background = Color(0xFF111318),
    onBackground = Color(0xFFE2E2E9),
    surface = Color(0xFF111318),
    onSurface = Color(0xFFE2E2E9),
    surfaceVariant = Color(0xFF43474E),
    onSurfaceVariant = Color(0xFFC3C6D0),
    outline = Color(0xFF8D919A),
    outlineVariant = Color(0xFF43474E),
)

private val LightColorScheme = lightColorScheme(
    primary = Color(0xFF365CA8),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFD9E2FF),
    onPrimaryContainer = Color(0xFF001944),
    secondary = Color(0xFF4F6078),
    onSecondary = Color(0xFFFFFFFF),
    secondaryContainer = Color(0xFFD2E4FF),
    onSecondaryContainer = Color(0xFF091D33),
    tertiary = Color(0xFF356848),
    onTertiary = Color(0xFFFFFFFF),
    tertiaryContainer = Color(0xFFB8EFC6),
    onTertiaryContainer = Color(0xFF00210D),
    error = Color(0xFFBA1A1A),
    onError = Color(0xFFFFFFFF),
    errorContainer = Color(0xFFFFDAD6),
    onErrorContainer = Color(0xFF410002),
    background = Color(0xFFF9F9FF),
    onBackground = Color(0xFF1A1C20),
    surface = Color(0xFFF9F9FF),
    onSurface = Color(0xFF1A1C20),
    surfaceVariant = Color(0xFFDFE2EB),
    onSurfaceVariant = Color(0xFF43474E),
    outline = Color(0xFF737780),
    outlineVariant = Color(0xFFC3C6D0),
)

@Composable
fun PinballTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val colorScheme: ColorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }

        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = MaterialTheme.typography,
        content = content,
    )
}
