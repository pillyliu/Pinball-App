package com.pillyliu.pinprofandroid.settings

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.CancellationSignal
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import com.pillyliu.pinprofandroid.library.LibraryVenueSearchResult
import com.pillyliu.pinprofandroid.ui.AnchoredDropdownFilter
import com.pillyliu.pinprofandroid.ui.AppCardSubheading
import com.pillyliu.pinprofandroid.ui.AppInlineTaskStatus
import com.pillyliu.pinprofandroid.ui.AppPrimaryButton
import com.pillyliu.pinprofandroid.ui.CardContainer
import com.pillyliu.pinprofandroid.ui.DropdownOption
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

internal data class VenueSearchCoordinate(
    val latitude: Double,
    val longitude: Double,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SettingsVenueSearchCard(
    query: String,
    onQueryChange: (String) -> Unit,
    radiusMiles: Int,
    onRadiusMilesChange: (Int) -> Unit,
    minimumGameCount: Int,
    onMinimumGameCountChange: (Int) -> Unit,
    searching: Boolean,
    locating: Boolean,
    error: String?,
    onSearch: () -> Unit,
    onSearchSubmit: () -> Unit,
    onCurrentLocation: () -> Unit,
) {
    CardContainer {
        LinkedHtmlText(
            html = """Search powered by <a href="https://www.pinballmap.com">Pinball Map</a>""",
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = query,
            onValueChange = onQueryChange,
            label = { Text("City or ZIP code") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            trailingIcon = {
                if (locating) {
                    CircularProgressIndicator(modifier = Modifier.padding(8.dp))
                } else {
                    IconButton(
                        onClick = onCurrentLocation,
                        enabled = !searching,
                    ) {
                        Icon(
                            imageVector = Icons.Filled.MyLocation,
                            contentDescription = "Use current location",
                        )
                    }
                }
            },
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = { onSearchSubmit() }),
        )
        AnchoredDropdownFilter(
            selectedText = "$radiusMiles miles",
            options = listOf(10, 25, 50, 100).map { miles ->
                DropdownOption(value = miles.toString(), label = "$miles miles")
            },
            onSelect = { value -> onRadiusMilesChange(value.toInt()) },
            label = "Distance",
        )
        OutlinedTextField(
            value = minimumGameCount.toString(),
            onValueChange = { onMinimumGameCountChange(it.toIntOrNull()?.coerceAtLeast(0) ?: minimumGameCount) },
            label = { Text("Minimum games") },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
        )
        AppPrimaryButton(
            onClick = onSearch,
            modifier = Modifier.fillMaxWidth(),
            enabled = !searching && !locating && query.isNotBlank(),
        ) {
            Text(if (searching) "Searching..." else "Search Pinball Map")
        }
        when {
            locating -> AppInlineTaskStatus(text = "Getting current location…", showsProgress = true)
            searching -> AppInlineTaskStatus(text = "Searching Pinball Map…", showsProgress = true)
            error != null -> AppInlineTaskStatus(text = error, isError = true)
        }
    }
}

@Composable
internal fun SettingsVenueResultCard(
    result: LibraryVenueSearchResult,
    searching: Boolean,
    onImport: () -> Unit,
) {
    CardContainer {
        androidx.compose.foundation.layout.Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            AppCardSubheading(result.name)
            val locationLine = listOfNotNull(result.city, result.state, result.zip).joinToString(", ")
            if (locationLine.isNotBlank()) {
                Text(locationLine, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text(
                buildString {
                    append("${result.machineCount} games")
                    result.distanceMiles?.let { append(" • ${"%.1f".format(it)} miles") }
                },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            AppPrimaryButton(
                onClick = onImport,
                modifier = Modifier.fillMaxWidth(),
                enabled = !searching,
            ) {
                Text("Import Venue")
            }
        }
    }
}

internal suspend fun currentVenueSearchCoordinate(context: Context): VenueSearchCoordinate =
    suspendCancellableCoroutine { continuation ->
        val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (locationManager == null) {
            continuation.resumeWithException(IllegalStateException("Location services are unavailable on this device."))
            return@suspendCancellableCoroutine
        }

        val fineGranted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val coarseGranted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (!fineGranted && !coarseGranted) {
            continuation.resumeWithException(IllegalStateException("Location permission is required to search near you."))
            return@suspendCancellableCoroutine
        }

        val provider = when {
            fineGranted && locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            fineGranted -> LocationManager.GPS_PROVIDER
            coarseGranted -> LocationManager.NETWORK_PROVIDER
            else -> null
        }
        val lastKnownLocation = sequenceOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
            .filter { providerName ->
                providerName != LocationManager.GPS_PROVIDER || fineGranted
            }
            .mapNotNull { providerName ->
                runCatching { locationManager.getLastKnownLocation(providerName) }.getOrNull()
            }
            .maxByOrNull(Location::getTime)

        if (provider == null) {
            val fallback = lastKnownLocation
            if (fallback != null) {
                continuation.resume(VenueSearchCoordinate(fallback.latitude, fallback.longitude))
            } else {
                continuation.resumeWithException(IllegalStateException("Turn on Location Services to search near you."))
            }
            return@suspendCancellableCoroutine
        }

        val cancellationSignal = CancellationSignal()
        continuation.invokeOnCancellation { cancellationSignal.cancel() }
        LocationManagerCompat.getCurrentLocation(
            locationManager,
            provider,
            cancellationSignal,
            ContextCompat.getMainExecutor(context),
        ) { location ->
            if (!continuation.isActive) return@getCurrentLocation
            val resolvedLocation = location ?: lastKnownLocation
            if (resolvedLocation != null) {
                continuation.resume(VenueSearchCoordinate(resolvedLocation.latitude, resolvedLocation.longitude))
            } else {
                continuation.resumeWithException(IllegalStateException("Couldn't get your current location."))
            }
        }
    }
