package com.plantapp.ui.customer

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.plantapp.data.Catalog
import com.plantapp.data.Listing
import com.plantapp.data.SellerInfo
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
    data class Shop(val sellerId: String) : Overlay
    data object Checkout : Overlay
    data class OrderDetail(val orderId: String) : Overlay
    data class Placed(val count: Int) : Overlay
}

sealed interface CheckoutError {
    data class NotDeliverable(val shops: List<String>) : CheckoutError
    /** The shop changed a price or delivery fee since the cart was filled (or the app sent wrong numbers). */
    data object PriceChanged : CheckoutError
    /** A product is gone, out of stock or its choices changed. */
    data object Unavailable : CheckoutError
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

/** What is stored for one cart line: which product, the customer's option choices, how many. */
data class CartEntry(val listingId: String, val options: Map<String, String>, val qty: Int)

/** Same product with different choices (blue vs black) is a different line. */
fun cartKey(listingId: String, options: Map<String, String>): String =
    listingId + options.toSortedMap().entries.joinToString("") { "|${it.key}=${it.value}" }

/** One line in the cart, with its product looked up. */
data class CartLine(val key: String, val listing: Listing, val options: Map<String, String>, val qty: Int) {
    val total: Int get() = listing.priceIqd * qty
}

/** The cart lines of one shop: they become one order and carry one delivery fee. */
data class ShopGroup(val sellerId: String, val shop: SellerInfo?, val lines: List<CartLine>, val fee: Int) {
    val subtotal: Int get() = lines.sumOf { it.total }
    val total: Int get() = subtotal + fee
}

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
    val cart: Map<String, CartEntry> = emptyMap(),
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
    val cartCount: Int get() = cart.values.sumOf { it.qty }

    /** Cart contents, skipping listings that no longer exist. */
    val cartLines: List<CartLine>
        get() = cart.mapNotNull { (key, entry) ->
            listings.firstOrNull { it.id == entry.listingId }?.let { CartLine(key, it, entry.options, entry.qty) }
        }

    /** The cart split by shop, each with the delivery fee for [city]. */
    fun cartGroups(city: String): List<ShopGroup> =
        cartLines.groupBy { it.listing.sellerId }.map { (sellerId, lines) ->
            val shop = lines.first().listing.sellers
            ShopGroup(sellerId, shop, lines, shop?.feeFor(city) ?: 0)
        }

    /** Everything to pay in cash: items plus every shop's delivery fee. */
    fun grandTotal(city: String): Int = cartGroups(city).sumOf { it.total }

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

class CustomerViewModel(initialProfile: Profile) : ViewModel() {
    /** The signed-in customer; replaced when they edit their profile. */
    private var profile: Profile = initialProfile

    fun setProfile(updated: Profile) { profile = updated }

    private val listingsRepo = ListingsRepository()
    private val ordersRepo = OrdersRepository()
    private val _state = MutableStateFlow(CustomerState(city = initialProfile.city.ifBlank { "Baghdad" }))
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

    /** Jump from the Smart Assistant to the products it suggested: a section (and category) or an occasion. */
    fun browse(section: String?, category: String?, occasion: String?) = _state.update {
        val useSection = section?.takeIf { s -> Catalog.section(s) != null }
        it.copy(
            overlay = null, entered = true, tab = CustomerTab.Browse, query = "", showAll = false,
            section = useSection,
            category = if (useSection != null) category?.takeIf { c -> Catalog.section(useSection)?.categories?.any { k -> k.key == c } == true } else null,
            occasion = if (useSection == null) occasion?.takeIf { o -> Catalog.occasions.any { k -> k.key == o } } else null,
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
    fun openShop(sellerId: String) = _state.update { it.copy(overlay = Overlay.Shop(sellerId)) }
    fun openCheckout() = _state.update { it.copy(overlay = Overlay.Checkout, checkoutError = null) }
    fun openOrder(id: String) = _state.update { it.copy(overlay = Overlay.OrderDetail(id)) }
    fun closeOverlay() = _state.update { it.copy(overlay = null) }

    /** Leaves the "order placed" page and shows the orders tab. */
    fun finishPlaced() = _state.update { it.copy(overlay = null, tab = CustomerTab.Orders) }

    fun addToCart(listingId: String, options: Map<String, String>) = _state.update { s ->
        val key = cartKey(listingId, options)
        val current = s.cart[key]
        s.copy(cart = s.cart + (key to CartEntry(listingId, options, (current?.qty ?: 0) + 1)))
    }

    fun changeQuantity(key: String, delta: Int) = _state.update { s ->
        val entry = s.cart[key] ?: return@update s
        val next = entry.qty + delta
        s.copy(cart = if (next <= 0) s.cart - key else s.cart + (key to entry.copy(qty = next)))
    }

    /** Creates one order per shop in the cart (cash on delivery); each carries that shop's delivery fee. */
    fun placeOrders(form: CheckoutForm) {
        val groups = _state.value.cartGroups(form.city)
        if (groups.isEmpty()) return

        val blocked = groups.filter { group -> group.lines.any { !it.listing.deliversTo(form.city) } }
            .mapNotNull { it.shop?.name }
            .distinct()
        if (blocked.isNotEmpty()) {
            _state.update { it.copy(checkoutError = CheckoutError.NotDeliverable(blocked)) }
            return
        }

        _state.update { it.copy(placing = true, checkoutError = null) }
        viewModelScope.launch {
            var created = 0
            var error: CheckoutError? = null
            for (group in groups) {
                val items = group.lines.map { line ->
                    OrderItem(line.listing.id, line.listing.name, line.qty, line.listing.priceIqd, line.options)
                }
                try {
                    ordersRepo.create(
                        NewOrder(
                            buyerId = profile.id,
                            sellerId = group.sellerId,
                            sellerName = group.shop?.name.orEmpty(),
                            items = items,
                            city = form.city,
                            address = form.address,
                            totalIqd = group.total,
                            deliveryFeeIqd = group.fee,
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
                    val keys = group.lines.map { it.key }.toSet()
                    _state.update { it.copy(cart = it.cart - keys) }
                    created++
                } catch (e: Exception) {
                    val reason = e.message.orEmpty()
                    error = when {
                        e is IOException -> CheckoutError.Network
                        "price_changed" in reason -> CheckoutError.PriceChanged
                        "unavailable" in reason -> CheckoutError.Unavailable
                        else -> CheckoutError.Generic
                    }
                    break
                }
            }
            if (created > 0) loadOrders()
            // Prices or stock changed: reload the products so the cart shows what the shop charges now.
            if (error == CheckoutError.PriceChanged || error == CheckoutError.Unavailable) load()
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
