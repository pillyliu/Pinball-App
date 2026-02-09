package com.pillyliu.pinballandroid.info

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pillyliu.pinballandroid.R
import com.pillyliu.pinballandroid.ui.AppScreen
import com.pillyliu.pinballandroid.ui.ControlBg
import com.pillyliu.pinballandroid.ui.ControlBorder
import com.pillyliu.pinballandroid.ui.SectionTitle

private const val WEBSITE_URL = "https://www.lansingpinleague.com/"
private const val FACEBOOK_URL = "https://www.facebook.com/groups/LansingPinLeague/"

@Composable
fun AboutScreen(contentPadding: PaddingValues) {
    val uriHandler = LocalUriHandler.current

    AppScreen(contentPadding) {
        Box(modifier = Modifier.fillMaxSize()) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(bottom = 30.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Image(
                    painter = painterResource(id = R.drawable.splash_logo),
                    contentDescription = "Lansing Pinball League logo",
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 140.dp, max = 210.dp),
                    contentScale = ContentScale.Fit,
                )

                Text(
                    text = "Pinball in the Capital City",
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White.copy(alpha = 0.92f),
                )
                Text(
                    text = "The Lansing Pinball League is the Capital City's IFPA-endorsed pinball league, open to players of all skill levels. New players are always welcome. We're a friendly, casual group with everyone from first-timers to seasoned competitors.",
                    color = Color.White.copy(alpha = 0.92f),
                )
                Text(
                    text = buildAnnotatedString {
                        append("We meet the 2nd and 4th Tuesdays at ")
                        pushStyle(SpanStyle(fontWeight = FontWeight.Bold))
                        append("The Avenue Cafe")
                        pop()
                        append(" (2021 E. Michigan Ave, Lansing), about halfway between MSU and the Capitol. We're currently in ")
                        pushStyle(SpanStyle(fontWeight = FontWeight.Bold))
                        append("Season 24")
                        pop()
                        append(", which started in January. New members can join during the first 5 meetings, and players must attend at least 4 of the 8 meetings to qualify for finals. Guests are welcome at any session. ")
                        pushStyle(SpanStyle(fontWeight = FontWeight.Bold))
                        append("Season dues are $10")
                        pop()
                        append(", paid in cash.")
                    },
                    color = Color.White.copy(alpha = 0.92f),
                )
                Text(
                    text = buildAnnotatedString {
                        append("We also run a side tournament, ")
                        pushStyle(SpanStyle(fontWeight = FontWeight.Bold))
                        append("Tuesday Night Smackdown")
                        pop()
                        append(", played on a single game. Qualifying starts around ")
                        pushStyle(SpanStyle(fontWeight = FontWeight.Bold))
                        append("6 pm")
                        pop()
                        append(", with finals (top 8 players) after league play finishes, usually around ")
                        pushStyle(SpanStyle(fontWeight = FontWeight.Bold))
                        append("9:30 pm")
                        pop()
                        append(".")
                    },
                    color = Color.White.copy(alpha = 0.92f),
                )

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 6.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Button(
                        onClick = { uriHandler.openUri(WEBSITE_URL) },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = ControlBg),
                        border = BorderStroke(1.dp, ControlBorder),
                    ) {
                        Text("lansingpinleague.com", color = Color.White)
                    }
                    Button(
                        onClick = { uriHandler.openUri(FACEBOOK_URL) },
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = ControlBg),
                        border = BorderStroke(1.dp, ControlBorder),
                    ) {
                        Text("Facebook Group", color = Color.White)
                    }
                }
            }

            Text(
                text = "Source: lansingpinleague.com",
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 2.dp),
                color = Color.White.copy(alpha = 0.7f),
                fontSize = 11.sp,
            )
        }
    }
}
