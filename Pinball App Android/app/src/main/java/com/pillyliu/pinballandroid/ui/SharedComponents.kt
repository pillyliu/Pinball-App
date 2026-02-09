package com.pillyliu.pinballandroid.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

data class DropdownOption(val value: String, val label: String)

@Composable
fun FixedWidthTableCell(
    text: String,
    width: Int,
    modifier: Modifier = Modifier,
    bold: Boolean = false,
    color: Color = Color.White,
    fontSize: TextUnit = 13.sp,
    maxLines: Int = 1,
    horizontalPadding: Dp = 3.dp,
    overflow: TextOverflow = TextOverflow.Clip,
) {
    Text(
        text = text,
        modifier = modifier.width(width.dp).padding(horizontal = horizontalPadding),
        color = color,
        fontWeight = if (bold) FontWeight.SemiBold else FontWeight.Normal,
        fontSize = fontSize,
        maxLines = maxLines,
        overflow = overflow,
    )
}

@Composable
fun CompactDropdownFilter(
    selectedText: String,
    options: List<String>,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
    minHeight: Dp = 34.dp,
    contentPadding: androidx.compose.foundation.layout.PaddingValues =
        androidx.compose.foundation.layout.PaddingValues(horizontal = 10.dp, vertical = 3.dp),
    textSize: TextUnit = 12.sp,
    itemTextSize: TextUnit = 12.sp,
) {
    var expanded by remember { mutableStateOf(false) }
    val density = LocalDensity.current
    var menuWidth by remember { mutableStateOf(0.dp) }
    Box(modifier = modifier.fillMaxWidth()) {
        OutlinedButton(
            onClick = { expanded = true },
            modifier = Modifier
                .fillMaxWidth()
                .defaultMinSize(minHeight = minHeight)
                .onGloballyPositioned { coordinates ->
                    menuWidth = with(density) { coordinates.size.width.toDp() }
                },
            contentPadding = contentPadding,
            shape = androidx.compose.foundation.shape.RoundedCornerShape(10.dp),
            colors = ButtonDefaults.outlinedButtonColors(
                containerColor = ControlBg,
                contentColor = Color.White,
            ),
            border = androidx.compose.foundation.BorderStroke(1.dp, ControlBorder),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Start,
            ) {
                Text(selectedText, fontSize = textSize, maxLines = 1)
                androidx.compose.foundation.layout.Spacer(modifier = Modifier.weight(1f))
                Icon(
                    imageVector = Icons.Filled.KeyboardArrowDown,
                    contentDescription = null,
                    tint = Color(0xFFC6C6C6),
                )
            }
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = if (menuWidth > 0.dp) Modifier.width(menuWidth) else Modifier,
        ) {
            options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option, fontSize = itemTextSize) },
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
fun AnchoredDropdownFilter(
    selectedText: String,
    options: List<DropdownOption>,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
    minHeight: Dp = 40.dp,
    contentPadding: PaddingValues = PaddingValues(start = 10.dp, end = 28.dp, top = 7.dp, bottom = 7.dp),
    buttonTextSize: TextUnit = 13.sp,
    itemTextSize: TextUnit = 12.sp,
) {
    var expanded by remember { mutableStateOf(false) }
    val density = LocalDensity.current
    var menuWidth by remember { mutableStateOf(0.dp) }
    Box(modifier = modifier.fillMaxWidth()) {
        OutlinedButton(
            onClick = { expanded = true },
            modifier = Modifier
                .fillMaxWidth()
                .defaultMinSize(minHeight = minHeight)
                .onGloballyPositioned { coordinates ->
                    menuWidth = with(density) { coordinates.size.width.toDp() }
                },
            contentPadding = contentPadding,
            shape = androidx.compose.foundation.shape.RoundedCornerShape(11.dp),
            border = androidx.compose.foundation.BorderStroke(1.dp, ControlBorder),
            colors = ButtonDefaults.outlinedButtonColors(
                containerColor = ControlBg,
                contentColor = Color.White,
            ),
        ) {
            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    selectedText,
                    modifier = Modifier.weight(1f),
                    fontSize = buttonTextSize,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(modifier = Modifier.width(6.dp))
            }
        }
        Icon(
            imageVector = Icons.Filled.KeyboardArrowDown,
            contentDescription = null,
            tint = Color(0xFFC6C6C6),
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .padding(end = 8.dp),
        )
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = if (menuWidth > 0.dp) Modifier.width(menuWidth) else Modifier,
        ) {
            options.forEach { option ->
                DropdownMenuItem(
                    text = { Text(option.label, fontSize = itemTextSize) },
                    onClick = {
                        expanded = false
                        onSelect(option.value)
                    },
                )
            }
        }
    }
}
