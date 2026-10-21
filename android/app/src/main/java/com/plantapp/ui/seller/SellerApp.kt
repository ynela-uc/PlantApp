package com.plantapp.ui.seller

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.delay
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.plantapp.R
import com.plantapp.data.Profile
import com.plantapp.ui.customer.rememberLang
import com.plantapp.ui.theme.ScreenBackground
import com.plantapp.ui.theme.SellerAmber
import com.plantapp.ui.theme.SellerAmberSoft
import com.plantapp.ui.theme.TextMuted

/** The signed-in seller experience: orders, plants and shop tabs, with full-screen pages on top. */
@Composable
fun SellerApp(profile: Profile, onSignOut: () -> Unit) {
    val vm: SellerViewModel = viewModel(
        factory = viewModelFactory { initializer { SellerViewModel(profile) } }
    )
    val state by vm.state.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current.lifecycle

    // While the app is on screen, look for new orders every 30 seconds (pushes cover the app being closed).
    LaunchedEffect(lifecycle) {
        lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
            while (true) {
                vm.refreshOrders()
                delay(30_000)
            }
        }
    }
    LaunchedEffect(state.alertOrders.joinToString { it.id }) {
        if (state.alertOrders.isNotEmpty()) playNewOrderAlert(context)
    }

    Box(Modifier.fillMaxSize()) {
        SellerScreens(vm, state, profile, onSignOut)
        NewOrderBanner(state.alertOrders, onOpen = vm::openAlert, onDismiss = vm::dismissAlert, modifier = Modifier.align(Alignment.TopCenter))
    }
}

@Composable
private fun SellerScreens(vm: SellerViewModel, state: SellerState, profile: Profile, onSignOut: () -> Unit) {

    if (state.loading) {
        Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator(color = SellerAmber) }
        return
    }
    val shop = state.shop
    if (state.failed || shop == null) {
        Column(
            Modifier.fillMaxSize().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(stringResource(R.string.seller_load_failed), color = TextMuted, textAlign = TextAlign.Center)
            Spacer(Modifier.height(12.dp))
            Button(onClick = vm::load) { Text(stringResource(R.string.retry)) }
            Spacer(Modifier.height(8.dp))
            Button(onClick = onSignOut) { Text(stringResource(R.string.action_signout)) }
        }
        return
    }

    // Full-screen pages on top of the tabs.
    val editor = state.editor
    if (editor != null) {
        BackHandler { vm.closeEditor() }
        val lang = rememberLang()
        PlantEditorScreen(
            editor = editor,
            onBack = vm::closeEditor,
            onPhoto = { raw -> vm.onPlantPhoto(raw, runAiNow = editor.listingId == null) },
            onRunAi = vm::runAi,
            onText = { field, value -> vm.setText(field, lang, value) },
            onScientific = vm::setScientificName,
            onHeight = vm::setHeight,
            onPrice = vm::setPrice,
            onStock = vm::setInStock,
            onSave = vm::saveEditor,
            onSection = vm::setSection,
            onCategory = vm::setCategory,
            onOccasion = vm::toggleOccasion,
            onUpdate = vm::updateEditor,
        )
        return
    }
    when (val overlay = state.overlay) {
        is SellerOverlay.OrderDetail -> {
            val order = state.order(overlay.orderId)
            if (order != null) {
                BackHandler { vm.closeOverlay() }
                SellerOrderDetailScreen(
                    order = order,
                    busy = state.busyOrderId == order.id,
                    actionFailed = state.actionFailed,
                    onStatus = { vm.changeStatus(order.id, it) },
                    onPhoto = { vm.sendPreparationPhoto(order.id, it) },
                    onBack = vm::closeOverlay,
                )
                return
            }
        }
        SellerOverlay.ShopEditor -> {
            BackHandler { vm.closeOverlay() }
            ShopEditorScreen(shop = shop, saving = state.savingShop, onBack = vm::closeOverlay, onSave = vm::saveShop)
            return
        }
        null -> Unit
    }

    Scaffold(
        containerColor = ScreenBackground,
        bottomBar = {
            NavigationBar(containerColor = Color.White) {
                NavigationBarItem(
                    selected = state.tab == SellerTab.Orders,
                    onClick = { vm.setTab(SellerTab.Orders) },
                    icon = {
                        BadgedBox(badge = { if (state.newOrderCount > 0) Badge { Text(state.newOrderCount.toString()) } }) { Text("📦") }
                    },
                    label = { Text(stringResource(R.string.nav_seller_orders)) },
                    colors = navColors(),
                )
                NavItem(state.tab == SellerTab.Plants, "🪴", stringResource(R.string.nav_my_plants)) { vm.setTab(SellerTab.Plants) }
                NavItem(state.tab == SellerTab.Shop, "🏪", stringResource(R.string.nav_shop)) { vm.setTab(SellerTab.Shop) }
            }
        },
    ) { padding ->
        val content = Modifier.padding(padding)
        when (state.tab) {
            SellerTab.Orders -> SellerOrdersTab(state, onOpen = vm::openOrder, onRefresh = vm::refreshOrders, modifier = content)
            SellerTab.Plants -> SellerPlantsTab(
                state = state,
                onAdd = vm::newPlant,
                onEdit = vm::editPlant,
                onToggleStock = vm::toggleStock,
                onDelete = vm::deleteListing,
                modifier = content,
            )
            SellerTab.Shop -> ShopTab(shop = shop, profile = profile, onEdit = vm::openShopEditor, onSignOut = onSignOut, modifier = content)
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
    selectedTextColor = SellerAmber,
    indicatorColor = SellerAmberSoft,
)
