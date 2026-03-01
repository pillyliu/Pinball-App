package com.pillyliu.pinballandroid.settings

import com.pillyliu.pinballandroid.library.LibraryVenueSearchResult
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URLEncoder
import java.net.URL

internal object PinballMapClient {
    fun searchVenues(query: String, radiusMiles: Int): List<LibraryVenueSearchResult> {
        val trimmed = query.trim()
        if (trimmed.isBlank()) return emptyList()
        val encoded = URLEncoder.encode(trimmed, Charsets.UTF_8.name())
        val url = "https://pinballmap.com/api/v1/locations/closest_by_address.json?address=$encoded&max_distance=$radiusMiles&send_all_within_distance=true"
        val root = JSONObject(fetchText(url))
        val locations = root.optJSONArray("locations") ?: JSONArray()
        return buildList {
            for (i in 0 until locations.length()) {
                val location = locations.optJSONObject(i) ?: continue
                add(
                    LibraryVenueSearchResult(
                        id = "venue--pm-${location.optInt("id")}",
                        name = location.optString("name").trim(),
                        city = location.optString("city").trim().ifBlank { null },
                        state = location.optString("state").trim().ifBlank { null },
                        zip = location.optString("zip").trim().ifBlank { null },
                        distanceMiles = location.optDouble("distance").takeUnless { it.isNaN() },
                        machineCount = location.optInt("machine_count").takeIf { it > 0 }
                            ?: location.optInt("num_machines"),
                    ),
                )
            }
        }
    }

    fun fetchVenueMachineIds(locationId: String): List<String> {
        val trimmed = locationId.trim()
        if (trimmed.isBlank()) return emptyList()
        val root = JSONObject(fetchText("https://pinballmap.com/api/v1/locations/$trimmed/machine_details.json"))
        val machines = root.optJSONArray("machines") ?: JSONArray()
        return buildList {
            for (i in 0 until machines.length()) {
                val machine = machines.optJSONObject(i) ?: continue
                val opdbId = machine.optString("opdb_id").trim()
                if (opdbId.isNotBlank()) add(opdbId)
            }
        }
    }

    private fun fetchText(url: String): String {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            connectTimeout = 15000
            readTimeout = 20000
            requestMethod = "GET"
        }
        val status = connection.responseCode
        if (status !in 200..299) error("Pinball Map request failed ($status)")
        return connection.inputStream.bufferedReader().use { it.readText() }
    }
}
