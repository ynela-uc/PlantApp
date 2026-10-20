package com.plantapp.ui.customer

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.plantapp.R
import com.plantapp.data.Profile
import com.plantapp.ui.theme.PlantGreen
import com.plantapp.ui.theme.PlantGreenSoft
import com.plantapp.ui.theme.ScreenBackground

/** The signed-in customer experience: browse, cart, orders and profile tabs, plus full-screen pages on top. */
@Composable
fun CustomerApp(profile: Profile, onSignOut: () -> Unit) {
    val vm: CustomerViewModel = viewModel(
        factory = viewModelFactory { initializer { CustomerViewModel(profile) } }
    )
    val state by vm.state.collectAsStateWithLifecycle()
    val assistant: AssistantViewModel = viewModel()
    val assistantState by assistant.state.collectAsStateWithLifecycle()
    val language = rememberLang()

    if (!state.entered) {
        EntryScreen(profile = profile, onChoose = vm::enter)
        return
    }

    when (val overlay = state.overlay) {
        is Overlay.Detail -> {
            val listing = state.listing(overlay.listingId)
            if (listing != null) {
                BackHandler { vm.closeOverlay() }
                ListingDetailScreen(
                    listing = listing,
                    inCart = state.cart[listing.id] ?: 0,
                    onAdd = { vm.changeQuantity(listing.id, 1) },
                    onBack = vm::closeOverlay,
                )
                return
            }
        }
        Overlay.Checkout -> {
            BackHandler { vm.closeOverlay() }
            CheckoutScreen(
                state = state,
                profile = profile,
                onBack = vm::closeOverlay,
                onPlace = vm::placeOrders,
            )
            return
        }
        is Overlay.OrderDetail -> {
            val order = state.order(overlay.orderId)
            if (order != null) {
                BackHandler { vm.closeOverlay() }
                OrderDetailScreen(
                    order = order,
                    reviewBusy = state.reviewBusy,
                    onReview = { approve, note -> vm.reviewPhoto(order.id, approve, note) },
                    onBack = vm::closeOverlay,
                )
                return
            }
        }
        is Overlay.Placed -> {
            BackHandler { vm.finishPlaced() }
            OrderPlacedScreen(
                count = overlay.count,
                onViewOrders = vm::finishPlaced,
                onKeepShopping = vm::closeOverlay,
            )
            return
        }
        null -> Unit
    }

    Scaffold(
        containerColor = ScreenBackground,
        bottomBar = {
            NavigationBar(containerColor = Color.White) {
                NavItem(state.tab == CustomerTab.Browse, "🌿", stringResource(R.string.nav_browse)) {
                    vm.setTab(CustomerTab.Browse)
                }
                NavItem(state.tab == CustomerTab.Assistant, "✨", stringResource(R.string.nav_ai)) {
                    vm.setTab(CustomerTab.Assistant)
                }
                NavigationBarItem(
                    selected = state.tab == CustomerTab.Cart,
                    onClick = { vm.setTab(CustomerTab.Cart) },
                    icon = {
                        BadgedBox(badge = { if (state.cartCount > 0) Badge { Text(state.cartCount.toString()) } }) {
                            Text("🛒")
                        }
                    },
                    label = { Text(stringResource(R.string.nav_cart)) },
                    colors = navColors(),
                )
                NavItem(state.tab == CustomerTab.Orders, "📦", stringResource(R.string.nav_orders)) {
                    vm.setTab(CustomerTab.Orders)
                }
                NavItem(state.tab == CustomerTab.Profile, "👤", stringResource(R.string.nav_profile)) {
                    vm.setTab(CustomerTab.Profile)
                }
            }
        },
    ) { padding ->
        val content = Modifier.padding(padding)
        when (state.tab) {
            CustomerTab.Browse -> BrowseScreen(
                profile = profile,
                state = state,
                onCity = vm::setCity,
                onQuery = vm::setQuery,
                onSection = vm::openSection,
                onCategory = vm::setCategory,
                onOccasion = vm::openOccasion,
                onOpen = vm::openListing,
                onRetry = vm::load,
                modifier = content,
            )
            CustomerTab.Assistant -> AssistantScreen(
                state = assistantState,
                customer = state,
                onSendText = { assistant.sendText(it, language) },
                onSendPhoto = { assistant.sendPhoto(it, language) },
                onNewChat = assistant::newChat,
                onOpenListing = vm::openListing,
                modifier = content,
            )
            CustomerTab.Cart -> CartScreen(
                state = state,
                onChangeQuantity = vm::changeQuantity,
                onOpen = vm::openListing,
                onCheckout = vm::openCheckout,
                modifier = content,
            )
            CustomerTab.Orders -> OrdersTab(
                state = state,
                onOpen = vm::openOrder,
                onRetry = vm::loadOrders,
                modifier = content,
            )
            CustomerTab.Profile -> ProfileTab(profile = profile, onSignOut = onSignOut, modifier = content)
        }
    }
}

@Composable
private fun RowScope.NavItem(selected: Boolean, emoji: String, label: String, onClick: () -> Unit) {
    NavigationBarItem(
        selected = selected,
        onClick = onClick,
        icon = { Text(emoji) },
        label = { Text(label) },
        colors = navColors(),
    )
}

@Composable
private fun navColors() = NavigationBarItemDefaults.colors(
    selectedTextColor = PlantGreen,
    indicatorColor = PlantGreenSoft,
)
