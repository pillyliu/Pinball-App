package com.pillyliu.pinballandroid.practice

import android.view.ViewGroup
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ItemTouchHelper
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.pillyliu.pinballandroid.library.PinballGame
import java.util.Collections

@Composable
internal fun NativeReorderSelectedCardsStrip(
    selectedSlugs: androidx.compose.runtime.snapshots.SnapshotStateList<String>,
    gamesBySlug: Map<String, PinballGame>,
    onRequestDelete: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val adapter = remember {
        SelectedCardsRecyclerAdapter(
            onCardClick = onRequestDelete,
        )
    }

    AndroidView(
        modifier = modifier
            .fillMaxWidth()
            .height(86.dp),
        factory = { context ->
            val recyclerView = RecyclerView(context).apply {
                overScrollMode = RecyclerView.OVER_SCROLL_NEVER
                layoutManager = LinearLayoutManager(context, RecyclerView.HORIZONTAL, false)
                clipToPadding = false
                setPadding(0, 0, 0, 0)
                this.adapter = adapter
            }

            val callback = object : ItemTouchHelper.SimpleCallback(
                ItemTouchHelper.LEFT or ItemTouchHelper.RIGHT,
                0,
            ) {
                override fun isLongPressDragEnabled(): Boolean = true

                override fun onMove(
                    recyclerView: RecyclerView,
                    viewHolder: RecyclerView.ViewHolder,
                    target: RecyclerView.ViewHolder,
                ): Boolean {
                    val from = viewHolder.bindingAdapterPosition
                    val to = target.bindingAdapterPosition
                    if (from == RecyclerView.NO_POSITION || to == RecyclerView.NO_POSITION || from == to) return false

                    adapter.move(from, to)
                    val moving = selectedSlugs.removeAt(from)
                    selectedSlugs.add(to, moving)
                    return true
                }

                override fun onSwiped(viewHolder: RecyclerView.ViewHolder, direction: Int) = Unit
            }
            ItemTouchHelper(callback).attachToRecyclerView(recyclerView)
            recyclerView
        },
        update = {
            adapter.submit(selectedSlugs.toList(), gamesBySlug)
        },
    )
}

private class SelectedCardsRecyclerAdapter(
    private val onCardClick: (String) -> Unit,
) : RecyclerView.Adapter<SelectedCardsRecyclerAdapter.CardViewHolder>() {
    private val slugs = mutableListOf<String>()
    private var gamesBySlug: Map<String, PinballGame> = emptyMap()

    class CardViewHolder(val composeView: ComposeView) : RecyclerView.ViewHolder(composeView)

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): CardViewHolder {
        val composeView = ComposeView(parent.context).apply {
            layoutParams = RecyclerView.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
        }
        return CardViewHolder(composeView)
    }

    override fun onBindViewHolder(holder: CardViewHolder, position: Int) {
        val slug = slugs[position]
        val game = gamesBySlug[slug] ?: return
        holder.composeView.setContent {
            Box(
                modifier = Modifier
                    .padding(end = 8.dp)
                    .clickable { onCardClick(slug) },
            ) {
                SelectedGameMiniCard(game = game)
            }
        }
    }

    override fun getItemCount(): Int = slugs.size

    fun move(from: Int, to: Int) {
        Collections.swap(slugs, from, to)
        notifyItemMoved(from, to)
    }

    fun submit(newSlugs: List<String>, newGamesBySlug: Map<String, PinballGame>) {
        val oldSlugs = slugs.toList()
        val gamesChanged = gamesBySlug !== newGamesBySlug
        gamesBySlug = newGamesBySlug
        if (oldSlugs == newSlugs) {
            if (gamesChanged && slugs.isNotEmpty()) {
                notifyItemRangeChanged(0, slugs.size)
            }
            return
        }
        val diff = DiffUtil.calculateDiff(
            object : DiffUtil.Callback() {
                override fun getOldListSize(): Int = oldSlugs.size
                override fun getNewListSize(): Int = newSlugs.size
                override fun areItemsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean =
                    oldSlugs[oldItemPosition] == newSlugs[newItemPosition]
                override fun areContentsTheSame(oldItemPosition: Int, newItemPosition: Int): Boolean =
                    oldSlugs[oldItemPosition] == newSlugs[newItemPosition]
            },
        )
        slugs.clear()
        slugs.addAll(newSlugs)
        diff.dispatchUpdatesTo(this)
        if (gamesChanged && slugs.isNotEmpty()) {
            notifyItemRangeChanged(0, slugs.size)
        }
    }
}
