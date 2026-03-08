package com.pillyliu.pinprofandroid.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

@Composable
fun AppSearchFilterBar(
    query: String,
    onQueryChange: (String) -> Unit,
    placeholder: String,
    onFilterClick: () -> Unit,
    modifier: Modifier = Modifier,
    minHeight: Dp = 48.dp,
    placeholderTextStyle: TextStyle = PinballThemeTokens.typography.dropdown,
    textStyle: TextStyle = PinballThemeTokens.typography.dropdown,
    filterContentDescription: String = "Filters",
) {
    val colors = PinballThemeTokens.colors
    val shapes = PinballThemeTokens.shapes
    val corner = shapes.controlCorner + 4.dp

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        OutlinedTextField(
            value = query,
            onValueChange = onQueryChange,
            placeholder = {
                Text(
                    text = placeholder,
                    color = colors.shellUnselectedContent,
                    style = placeholderTextStyle,
                    maxLines = 1,
                )
            },
            modifier = Modifier
                .weight(1f)
                .height(minHeight)
                .shadow(10.dp, RoundedCornerShape(corner), clip = false),
            shape = RoundedCornerShape(corner),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.None),
            textStyle = textStyle.copy(color = colors.shellSelectedContent),
            singleLine = true,
            colors = OutlinedTextFieldDefaults.colors(
                focusedTextColor = colors.shellSelectedContent,
                unfocusedTextColor = colors.shellSelectedContent,
                focusedLabelColor = colors.shellSelectedContent,
                unfocusedLabelColor = colors.shellUnselectedContent,
                cursorColor = colors.shellSelectedContent,
                focusedContainerColor = colors.controlBackground,
                unfocusedContainerColor = colors.controlBackground,
                focusedBorderColor = colors.controlBorder,
                unfocusedBorderColor = colors.controlBorder,
            ),
        )

        FilledTonalIconButton(
            onClick = onFilterClick,
            shape = RoundedCornerShape(corner),
            colors = IconButtonDefaults.filledTonalIconButtonColors(
                containerColor = colors.controlBackground,
                contentColor = colors.shellSelectedContent,
            ),
            modifier = Modifier
                .height(minHeight)
                .shadow(10.dp, RoundedCornerShape(corner), clip = false),
        ) {
            Icon(
                imageVector = Icons.Outlined.FilterList,
                contentDescription = filterContentDescription,
            )
        }
    }
}
