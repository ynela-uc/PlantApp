package com.plantapp.ui.customer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.plantapp.data.Listing
import com.plantapp.data.ListingsRepository
import com.plantapp.data.NewOrder
import com.plantapp.data.Order
import com.plantapp.data.OrderItem
import com.plantapp.data.OrdersRepository
import com.plantapp.data.Profile
import com.plantapp.data.deliversTo
import com.plantapp.data.localized
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.IOException

enum class CustomerTab { Browse, Assistant, Cart, Orders, Profile }

/** Full-screen pages shown on top of the tabs. */
sealed interface Overlay {
    data class Detail(val listingId: String) : Overlay
    data object Checkout : Overlay
    data class OrderDetail(val orderId: String) : Overlay
    data class Placed(val count: Int) : Overlay
}

sealed interface CheckoutError {
    data class NotDeliverable(val shops: List<String>) : CheckoutError
    data object Network : CheckoutError
    data object Generic : CheckoutError
}

/** Everything the customer fills in on the checkout page. */
data class CheckoutForm(
    val isGift: Boolean,
    val recipientName: String,
    val recipientPhone: String,
    val city: String,
    val address: String,
    val giftNote: String,
    /** ISO date, yyyy-MM-dd */
    val deliveryDate: String,
    /** any / morning / afternoon / evening */
    val window: String,
)

data class CustomerState(
    /** False until the shopper picks what to look at on the entry screen; asked again at every app start. */
    val entered: Boolean = false,
    val loading: Boolean = true,
    val failed: Boolean = false,
    val listings: List<Listing> = emptyList(),
    val city: String = "",
    val query: String = "",
    /** Home screen vs. browsing one section (flowers / plants / gifts), one category in it, or one occasion. */
    val section: String? = null,
    val category: String? = null,
    val occasion: String? = null,
    /** The entry screen's "show everything": a plain product list with no section chosen. */
    val showAll: Boolean = false,
    /** listing id -> quantity */
    val cart: Map<String, Int> = emptyMap(),
    val tab: CustomerTab = CustomerTab.Browse,
    val overlay: Overlay? = null,
    val orders: List<Order> = emptyList(),
    val ordersLoading: Boolean = false,
    val ordersFailed: Boolean = false,
    val placing: Boolean = false,
    val checkoutError: CheckoutError? = null,
    /** True while the customer's answer to a preparation photo is being saved. */
    val reviewBusy: Boolean = false,
) {
    val cartCount: Int get() = cart.values.sum()

    /** Cart contents as (listing, quantity), skipping listings that no longer exist. */
    val cartLines: List<Pair<Listing, Int>>
        get() = cart.mapNotNull { (id, qty) -> listings.firstOrNull { it.id == id }?.let { it to qty } }

    val cartTotal: Int get() = cartLines.sumOf { (listing, qty) -> listing.priceIqd * qty }

    fun listing(id: String): Listing? = listings.firstOrNull { it.id == id }
    fun order(id: String): Order? = orders.firstOrNull { it.id == id }

    /** Listings that can be delivered to [city] and are in stock. */
    val deliverable: List<Listing> get() = listings.filter { it.inStock && it.deliversTo(city) }

    /** True when no section, occasion or search is active: the screen shows the home page instead of a product list. */
    val isHome: Boolean get() = section == null && occasion == null && query.isBlank() && !showAll

    /** Deliverable listings matching the section, category, occasion and search text. */
    fun visible(lang: String): List<Listing> {
        val q = query.trim().lowercase()
        return deliverable.filter { listing ->
            (section == null || listing.section == section) &&
                (category == null || listing.category == category) &&
                (occasion == null || occasion in listing.occasions) &&
                (q.isEmpty() || listing.name.values.any { it.lowercase().contains(q) } ||
                    listing.name.localized(lang).lowercase().contains(q) ||
                    (listing.sellers?.name?.lowercase()?.contains(q) == true))
        }
    }

}

class CustomerViewModel(private val profile: Profile) : ViewModel() {
    private val listingsRepo = ListingsRepository()
    private val ordersRepo = OrdersRepository()
    private val _state = MutableStateFlow(CustomerState(city = profile.city.ifBlank { "Baghdad" }))
    val state: StateFlow<CustomerState> = _state.asStateFlow()

    init {
        load()
        loadOrders()
    }

    fun load() {
        _state.update { it.copy(loading = true, failed = false) }
        viewModelScope.launch {
            try {
                val all = listingsRepo.fetchAll()
                _state.update { it.copy(loading = false, listings = all) }
            } catch (_: Exception) {
                _state.update { it.copy(loading = false, failed = true) }
            }
        }
    }

    fun loadOrders() {
        _state.update { it.copy(ordersLoading = true, ordersFailed = false) }
        viewModelScope.launch {
            try {
                val mine = ordersRepo.fetchMine(profile.id)
                _state.update { it.copy(ordersLoading = false, orders = mine) }
            } catch (_: Exception) {
                _state.update { it.copy(ordersLoading = false, ordersFailed = true) }
            }
        }
    }

    /** Approve the shop's photo, or send the shop a change request. */
    fun reviewPhoto(orderId: String, approve: Boolean, note: String?) {
        _state.update { it.copy(reviewBusy = true) }
        viewModelScope.launch {
            try {
                ordersRepo.reviewPhoto(orderId, approve, note)
                loadOrders()
            } catch (_: Exception) { }
            _state.update { it.copy(reviewBusy = false) }
        }
    }

    /** Entry screen answer: open this section or occasion (both null = show everything) and show the app. */
    fun enter(section: String?, occasion: String?) = _state.update {
        it.copy(
            entered = true, section = section, occasion = occasion, category = null, query = "",
            showAll = section == null && occasion == null, tab = CustomerTab.Browse,
        )
    }

    fun setCity(city: String) = _state.update { it.copy(city = city, category = null) }
    fun setQuery(query: String) = _state.update { it.copy(query = query) }

    /** Opens one section (or goes back to the home page with null). */
    fun openSection(key: String?) = _state.update { it.copy(section = key, category = null, occasion = null, query = "", showAll = false) }
    fun setCategory(key: String?) = _state.update { it.copy(category = key) }

    /** Opens everything for one occasion across all sections (or goes back home with null). */
    fun openOccasion(key: String?) = _state.update { it.copy(occasion = key, section = null, category = null, query = "", showAll = false) }

    fun setTab(tab: CustomerTab) {
        _state.update { it.copy(tab = tab) }
        if (tab == CustomerTab.Orders) loadOrders()
    }

    fun openListing(id: String) = _state.update { it.copy(overlay = Overlay.Detail(id)) }
    fun openCheckout() = _state.update { it.copy(overlay = Overlay.Checkout, checkoutError = null) }
    fun openOrder(id: String) = _state.update { it.copy(overlay = Overlay.OrderDetail(id)) }
    fun closeOverlay() = _state.update { it.copy(overlay = null) }

    /** Leaves the "order placed" page and shows the orders tab. */
    fun finishPlaced() = _state.update { it.copy(overlay = null, tab = CustomerTab.Orders) }

    fun changeQuantity(listingId: String, delta: Int) = _state.update { s ->
        val next = (s.cart[listingId] ?: 0) + delta
        s.copy(cart = if (next <= 0) s.cart - listingId else s.cart + (listingId to next))
    }

    /** Creates one order per shop in the cart (cash on delivery). */
    fun placeOrders(form: CheckoutForm) {
        val lines = _state.value.cartLines
        if (lines.isEmpty()) return

        val blocked = lines.filter { !it.first.deliversTo(form.city) }
            .mapNotNull { it.first.sellers?.name }
            .distinct()
        if (blocked.isNotEmpty()) {
            _state.update { it.copy(checkoutError = CheckoutError.NotDeliverable(blocked)) }
            return
        }

        _state.update { it.copy(placing = true, checkoutError = null) }
        viewModelScope.launch {
            var created = 0
            var error: CheckoutError? = null
            for ((sellerId, group) in lines.groupBy { it.first.sellerId }) {
                val items = group.map { (listing, qty) ->
                    OrderItem(listing.id, listing.name, qty, listing.priceIqd)
                }
                try {
                    ordersRepo.create(
                        NewOrder(
                            buyerId = profile.id,
                            sellerId = sellerId,
                            sellerName = group.first().first.sellers?.name.orEmpty(),
                            items = items,
                            city = form.city,
                            address = form.address,
                            totalIqd = items.sumOf { it.qty * it.unitPriceIqd },
                            buyerName = "${profile.firstName} ${profile.lastName}".trim(),
                            buyerPhone = profile.phone,
                            isGift = form.isGift,
                            recipientName = form.recipientName.takeIf { form.isGift && it.isNotBlank() },
                            recipientPhone = form.recipientPhone.takeIf { form.isGift && it.isNotBlank() },
                            giftNote = form.giftNote.takeIf { form.isGift && it.isNotBlank() },
                            deliveryDate = form.deliveryDate,
                            deliveryWindow = form.window,
                        )
                    )
                    val ids = group.map { it.first.id }.toSet()
                    _state.update { it.copy(cart = it.cart - ids) }
                    created++
                } catch (e: Exception) {
                    error = if (e is IOException) CheckoutError.Network else CheckoutError.Generic
                    break
                }
            }
            if (created > 0) loadOrders()
            _state.update {
                it.copy(
                    placing = false,
                    checkoutError = error,
                    overlay = if (error == null) Overlay.Placed(created) else it.overlay,
                )
            }
        }
    }
}
