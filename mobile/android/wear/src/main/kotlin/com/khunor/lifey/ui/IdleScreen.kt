package com.khunor.lifey.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.khunor.lifey.R

/** No active session — docs/40-watch-app-plan.md §4.4/§5.1 "IdleView" equivalent. */
@Composable
fun IdleScreen() {
    Column(
        modifier = Modifier.fillMaxSize().padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(text = stringResource(R.string.idle_title), style = MaterialTheme.typography.title3)
        Text(
            text = stringResource(R.string.idle_subtitle),
            style = MaterialTheme.typography.caption1,
            textAlign = TextAlign.Center,
        )
    }
}
