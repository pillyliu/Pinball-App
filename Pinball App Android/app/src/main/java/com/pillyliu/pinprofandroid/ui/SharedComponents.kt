package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.material3.LocalTextStyle
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
    color: Color = Color.Unspecified,
    fontSize: TextUnit = PinballThemeTokens.typography.tableCell.fontSize,
    maxLines: Int = 1,
    horizontalPadding: Dp = 3.dp,
    overflow: TextOverflow = TextOverflow.Clip,
) {
    val colors = PinballThemeTokens.colors
    val typography = PinballThemeTokens.typography
    Text(
        text = text,
        modifier = modifier.width(width.dp).padding(horizontal = horizontalPadding),
        color = if (color == Color.Unspecified) colors.shellSelectedContent else color,
        fontWeight = if (bold) FontWeight.SemiBold else typography.tableCell.fontWeight ?: FontWeight.Normal,
        fontSize = fontSize,
        maxLines = maxLines,
        overflow = overflow,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CompactDropdownFilter(
    selectedText: String,
    options: List<String>,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
    minHeight: Dp = 34.dp,
    contentPadding: PaddingValues = PaddingValues(horizontal = PinballThemeTokens.spacing.controlHorizontal, vertical = 3.dp),
    textSize: TextUnit = PinballThemeTokens.typography.dropdown.fontSize,
    itemTextSize: TextUnit = PinballThemeTokens.typography.dropdownItem.fontSize,
) {
    val colors = PinballThemeTokens.colors
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = !expanded },
        modifier = modifier.fillMaxWidth(),
    ) {
        CompositionLocalProvider(
            LocalTextStyle provides LocalTextStyle.current.copy(fontSize = textSize),
        ) {
            OutlinedTextField(
                value = selectedText,
                onValueChange = {},
                readOnly = true,
                singleLine = true,
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                textStyle = LocalTextStyle.current.copy(fontSize = textSize),
                colors = ExposedDropdownMenuDefaults.outlinedTextFieldColors(
                    focusedContainerColor = colors.controlBackground,
                    unfocusedContainerColor = colors.controlBackground,
                    focusedBorderColor = colors.controlBorder,
                    unfocusedBorderColor = colors.controlBorder,
                    focusedTextColor = colors.shellSelectedContent,
                    unfocusedTextColor = colors.shellSelectedContent,
                    focusedTrailingIconColor = colors.shellUnselectedContent,
                    unfocusedTrailingIconColor = colors.shellUnselectedContent,
                ),
                modifier = Modifier
                    .menuAnchor(type = MenuAnchorType.PrimaryNotEditable)
                    .fillMaxWidth()
                    .defaultMinSize(minHeight = minHeight),
            )
        }
        ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier.fillMaxWidth(),
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AnchoredDropdownFilter(
    selectedText: String,
    options: List<DropdownOption>,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
    minHeight: Dp = 40.dp,
    contentPadding: PaddingValues = PaddingValues(
        start = PinballThemeTokens.spacing.controlHorizontal,
        end = 28.dp,
        top = PinballThemeTokens.spacing.controlVertical + 1.dp,
        bottom = PinballThemeTokens.spacing.controlVertical + 1.dp,
    ),
    buttonTextSize: TextUnit = PinballThemeTokens.typography.dropdown.fontSize,
    itemTextSize: TextUnit = PinballThemeTokens.typography.dropdownItem.fontSize,
) {
    val colors = PinballThemeTokens.colors
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(
        expanded = expanded,
        onExpandedChange = { expanded = !expanded },
        modifier = modifier.fillMaxWidth(),
    ) {
        OutlinedTextField(
            value = selectedText,
            onValueChange = {},
            readOnly = true,
            singleLine = true,
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            textStyle = LocalTextStyle.current.copy(fontSize = buttonTextSize),
            colors = ExposedDropdownMenuDefaults.outlinedTextFieldColors(
                focusedContainerColor = colors.controlBackground,
                unfocusedContainerColor = colors.controlBackground,
                focusedBorderColor = colors.controlBorder,
                unfocusedBorderColor = colors.controlBorder,
                focusedTextColor = colors.shellSelectedContent,
                unfocusedTextColor = colors.shellSelectedContent,
                focusedTrailingIconColor = colors.shellUnselectedContent,
                unfocusedTrailingIconColor = colors.shellUnselectedContent,
            ),
            modifier = Modifier
                .menuAnchor(type = MenuAnchorType.PrimaryNotEditable)
                .fillMaxWidth()
                .defaultMinSize(minHeight = minHeight),
        )
        ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier.fillMaxWidth(),
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
