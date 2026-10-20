package com.plantapp.ui.seller

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.plantapp.data.AiException
import com.plantapp.data.AiRepository
import com.plantapp.data.Catalog
import com.plantapp.data.Listing
import com.plantapp.data.ListingOption
import com.plantapp.data.ListingUpdate
import com.plantapp.data.NewListing
import com.plantapp.data.Order
import com.plantapp.data.OrderStatus
import com.plantapp.data.PlantSuggestion
import com.plantapp.data.Profile
import com.plantapp.data.SellerRepository
import com.plantapp.data.Shop
import com.plantapp.data.ShopUpdate
import com.plantapp.ui.ImageUtils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

enum class SellerTab { Orders, Plants, Shop }

sealed interface SellerOverlay {
    data class OrderDetail(val orderId: String) : SellerOverlay
    data object ShopEditor : SellerOverlay
}

/** The text fields of the plant editor that exist once per language. */
enum class TextField { Name, Description, Water, Light, Fertilizer }

/** What happened the last time the AI ran, shown above the editor fields. */
enum class AiMessage { Filled, LowConfidence, NotAPlant, NotConfigured, LimitReached, Network, Failed }

enum class EditorError { Required, CategoryMissing, SaveFailed }

/** One option group being edited: a name ("Colour") and its choices typed as "Blue, Black". */
data class OptionDraft(val name: String = "", val valuesText: String = "")

/** Everything in the add/edit plant page. Texts are maps keyed by language code (en / ar / ckb). */
class EditorState(
    val listingId: String? = null,
    val photoBytes: ByteArray? = null,
    val existingImagePath: String? = null,
    val plantKey: String? = null,
    val name: Map<String, String> = emptyMap(),
    val scientificName: String = "",
    val description: Map<String, String> = emptyMap(),
    val water: Map<String, String> = emptyMap(),
    val light: Map<String, String> = emptyMap(),
    val fertilizer: Map<String, String> = emptyMap(),
    val heightText: String = "",
    val priceText: String = "",
    val inStock: Boolean = true,
    val aiGenerated: Boolean = false,
    val aiBusy: Boolean = false,
    val aiMessage: AiMessage? = null,
    val saving: Boolean = false,
    val error: EditorError? = null,
    /** Catalog keys: which section and category this product is filed under, and its occasions. */
    val section: String? = null,
    val category: String? = null,
    val occasions: List<String> = emptyList(),
    val oldPriceText: String = "",
    val piecesText: String = "",
    val collection: String = "",
    val options: List<OptionDraft> = emptyList(),
) {
    fun copy(
        photoBytes: ByteArray? = this.photoBytes,
        plantKey: String? = this.plantKey,
        name: Map<String, String> = this.name,
        scientificName: String = this.scientificName,
        description: Map<String, String> = this.description,
        water: Map<String, String> = this.water,
        light: Map<String, String> = this.light,
        fertilizer: Map<String, String> = this.fertilizer,
        heightText: String = this.heightText,
        priceText: String = this.priceText,
        inStock: Boolean = this.inStock,
        aiGenerated: Boolean = this.aiGenerated,
        aiBusy: Boolean = this.aiBusy,
        aiMessage: AiMessage? = this.aiMessage,
        saving: Boolean = this.saving,
        error: EditorError? = this.error,
        section: String? = this.section,
        category: String? = this.category,
        occasions: List<String> = this.occasions,
        oldPriceText: String = this.oldPriceText,
        piecesText: String = this.piecesText,
        collection: String = this.collection,
        options: List<OptionDraft> = this.options,
    ) = EditorState(
        listingId, photoBytes, existingImagePath, plantKey, name, scientificName, description,
        water, light, fertilizer, heightText, priceText, inStock, aiGenerated, aiBusy, aiMessage, saving, error,
        section, category, occasions, oldPriceText, piecesText, collection, options,
    )
}

data class SellerState(
    val loading: Boolean = true,
    val failed: Boolean = false,
    val shop: Shop? = null,
    val listings: List<Listing> = emptyList(),
    val orders: List<Order> = emptyList(),
    val tab: SellerTab = SellerTab.Orders,
    val overlay: SellerOverlay? = null,
    val editor: EditorState? = null,
    /** Order currently being updated (buttons show a spinner). */
    val busyOrderId: String? = null,
    val actionFailed: Boolean = false,
    val savingShop: Boolean = false,
) {
    val newOrderCount: Int get() = orders.count { it.statusEnum == OrderStatus.Placed }
    fun order(id: String): Order? = orders.firstOrNull { it.id == id }
}

class SellerViewModel(private val profile: Profile) : ViewModel() {
    private val repo = SellerRepository()
    private val ai = AiRepository()
    private val _state = MutableStateFlow(SellerState())
    val state: StateFlow<SellerState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() {
        _state.update { it.copy(loading = true, failed = false) }
        viewModelScope.launch {
            try {
                val shop = repo.fetchShop(profile.id)
                if (shop == null) {
                    _state.update { it.copy(loading = false, failed = true) }
                    return@launch
                }
                val listings = repo.fetchListings(shop.id)
                val orders = repo.fetchOrders(shop.id)
                _state.update { it.copy(loading = false, shop = shop, listings = listings, orders = orders) }
            } catch (_: Exception) {
                _state.update { it.copy(loading = false, failed = true) }
            }
        }
    }

    private fun reloadOrders() {
        val shop = _state.value.shop ?: return
        viewModelScope.launch {
            try {
                val orders = repo.fetchOrders(shop.id)
                _state.update { it.copy(orders = orders) }
            } catch (_: Exception) { }
        }
    }

    private suspend fun reloadListings() {
        val shop = _state.value.shop ?: return
        val listings = repo.fetchListings(shop.id)
        _state.update { it.copy(listings = listings) }
    }

    fun setTab(tab: SellerTab) {
        _state.update { it.copy(tab = tab) }
        if (tab == SellerTab.Orders) reloadOrders()
    }

    fun refreshOrders() = reloadOrders()
    fun openOrder(id: String) = _state.update { it.copy(overlay = SellerOverlay.OrderDetail(id), actionFailed = false) }
    fun openShopEditor() = _state.update { it.copy(overlay = SellerOverlay.ShopEditor) }
    fun closeOverlay() = _state.update { it.copy(overlay = null) }

    // ------------------------------------------------------------------ orders

    fun changeStatus(orderId: String, status: OrderStatus) {
        _state.update { it.copy(busyOrderId = orderId, actionFailed = false) }
        viewModelScope.launch {
            try {
                repo.setOrderStatus(orderId, status)
                reloadOrdersNow()
                _state.update { it.copy(busyOrderId = null) }
            } catch (_: Exception) {
                _state.update { it.copy(busyOrderId = null, actionFailed = true) }
            }
        }
    }

    /** Uploads the photo of the prepared order and asks the customer to approve it. */
    fun sendPreparationPhoto(orderId: String, raw: ByteArray) {
        _state.update { it.copy(busyOrderId = orderId, actionFailed = false) }
        viewModelScope.launch {
            try {
                val jpeg = withContext(Dispatchers.Default) { ImageUtils.prepareJpeg(raw) }
                val path = repo.uploadOrderPhoto(orderId, jpeg)
                repo.setOrderStatus(orderId, OrderStatus.PhotoSent, path)
                reloadOrdersNow()
                _state.update { it.copy(busyOrderId = null) }
            } catch (_: Exception) {
                _state.update { it.copy(busyOrderId = null, actionFailed = true) }
            }
        }
    }

    private suspend fun reloadOrdersNow() {
        val shop = _state.value.shop ?: return
        val orders = repo.fetchOrders(shop.id)
        _state.update { it.copy(orders = orders) }
    }

    // ------------------------------------------------------------------ plants

    fun toggleStock(listing: Listing) {
        viewModelScope.launch {
            try {
                repo.setInStock(listing.id, !listing.inStock)
                reloadListings()
            } catch (_: Exception) { }
        }
    }

    fun deleteListing(id: String) {
        viewModelScope.launch {
            try {
                repo.deleteListing(id)
                reloadListings()
            } catch (_: Exception) { }
        }
    }

    fun newPlant() = _state.update { it.copy(editor = EditorState()) }

    fun editPlant(listing: Listing) = _state.update {
        it.copy(
            editor = EditorState(
                listingId = listing.id,
                existingImagePath = listing.imagePath,
                plantKey = listing.plantKey,
                name = listing.name,
                scientificName = listing.scientificName.orEmpty(),
                description = listing.description,
                water = listing.care["water"].orEmpty(),
                light = listing.care["light"].orEmpty(),
                fertilizer = listing.care["fertilizer"].orEmpty(),
                heightText = listing.heightCm?.toString().orEmpty(),
                priceText = listing.priceIqd.toString(),
                oldPriceText = listing.oldPriceIqd?.toString().orEmpty(),
                piecesText = listing.pieces?.toString().orEmpty(),
                collection = listing.collection.orEmpty(),
                options = listing.options.map { OptionDraft(it.name, it.values.joinToString(", ")) },
                inStock = listing.inStock,
                aiGenerated = listing.aiGenerated,
                section = listing.section,
                category = listing.category,
                occasions = listing.occasions,
            )
        )
    }

    fun closeEditor() = _state.update { it.copy(editor = null) }

    private fun editor(change: (EditorState) -> EditorState) = _state.update { s ->
        s.copy(editor = s.editor?.let(change))
    }

    fun setText(field: TextField, lang: String, value: String) = editor { e ->
        fun Map<String, String>.with() = this + (lang to value)
        when (field) {
            TextField.Name -> e.copy(name = e.name.with(), error = null)
            TextField.Description -> e.copy(description = e.description.with())
            TextField.Water -> e.copy(water = e.water.with())
            TextField.Light -> e.copy(light = e.light.with())
            TextField.Fertilizer -> e.copy(fertilizer = e.fertilizer.with())
        }
    }

    fun setScientificName(value: String) = editor { it.copy(scientificName = value) }
    fun setPlantKey(key: String?) = editor { it.copy(plantKey = key) }
    fun setHeight(value: String) = editor { it.copy(heightText = value.filter(Char::isDigit).take(3)) }
    fun setPrice(value: String) = editor { it.copy(priceText = value.filter(Char::isDigit).take(9), error = null) }
    fun setInStock(value: Boolean) = editor { it.copy(inStock = value) }

    /** Generic change used by the newer product fields (old price, pieces, collection, options). */
    fun updateEditor(change: (EditorState) -> EditorState) = editor(change)

    /** Picking another section clears a category that belongs to the old one. */
    fun setSection(key: String) = editor { e ->
        val stillValid = Catalog.section(key)?.categories?.any { it.key == e.category } == true
        e.copy(section = key, category = if (stillValid) e.category else null, error = null)
    }

    fun setCategory(key: String) = editor { it.copy(category = key, error = null) }

    fun toggleOccasion(key: String) = editor { e ->
        e.copy(occasions = if (key in e.occasions) e.occasions - key else e.occasions + key)
    }

    /** A new photo was taken or picked. For a new plant the AI runs straight away. */
    fun onPlantPhoto(raw: ByteArray, runAiNow: Boolean) {
        viewModelScope.launch {
            val jpeg = withContext(Dispatchers.Default) { ImageUtils.prepareJpeg(raw) }
            editor { it.copy(photoBytes = jpeg, aiMessage = null) }
            if (runAiNow) runAi()
        }
    }

    fun runAi() {
        val photo = _state.value.editor?.photoBytes ?: return
        editor { it.copy(aiBusy = true, aiMessage = null) }
        viewModelScope.launch {
            try {
                val suggestion = ai.identify(photo)
                editor { applySuggestion(it, suggestion) }
            } catch (e: AiException) {
                val message = when (e.kind) {
                    AiException.Kind.NotConfigured -> AiMessage.NotConfigured
                    AiException.Kind.LimitReached -> AiMessage.LimitReached
                    AiException.Kind.Network -> AiMessage.Network
                    AiException.Kind.Failed -> AiMessage.Failed
                }
                editor { it.copy(aiBusy = false, aiMessage = message) }
            } catch (_: Exception) {
                editor { it.copy(aiBusy = false, aiMessage = AiMessage.Failed) }
            }
        }
    }

    private fun applySuggestion(e: EditorState, s: PlantSuggestion): EditorState {
        if (!s.identified) return e.copy(aiBusy = false, aiMessage = AiMessage.NotAPlant)
        return e.copy(
            aiBusy = false,
            aiGenerated = true,
            aiMessage = if (s.confidence == "low") AiMessage.LowConfidence else AiMessage.Filled,
            plantKey = s.plantKey.takeIf { it != "Other" },
            section = Catalog.section(s.section)?.key ?: e.section,
            category = Catalog.section(s.section)?.categories?.firstOrNull { it.key == s.category }?.key ?: e.category,
            occasions = s.occasions.filter { key -> Catalog.occasions.any { it.key == key } }.ifEmpty { e.occasions },
            name = s.name.toMap(),
            scientificName = s.scientificName,
            description = s.description.toMap(),
            water = s.care.water.toMap(),
            light = s.care.light.toMap(),
            fertilizer = s.care.fertilizer.toMap(),
            heightText = if (s.heightCm > 0) s.heightCm.toString() else e.heightText,
        )
    }

    fun saveEditor() {
        val shop = _state.value.shop ?: return
        val e = _state.value.editor ?: return
        val price = e.priceText.toIntOrNull()
        if (e.name.values.none { it.isNotBlank() } || price == null || price <= 0) {
            editor { it.copy(error = EditorError.Required) }
            return
        }
        if (e.section == null || e.category == null) {
            editor { it.copy(error = EditorError.CategoryMissing) }
            return
        }
        editor { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            try {
                val imagePath = e.photoBytes?.let { repo.uploadPlantPhoto(profile.id, it) } ?: e.existingImagePath
                val name = e.name.filterValues { it.isNotBlank() }
                val description = e.description.filterValues { it.isNotBlank() }
                val care = mapOf(
                    "water" to e.water.filterValues { it.isNotBlank() },
                    "light" to e.light.filterValues { it.isNotBlank() },
                    "fertilizer" to e.fertilizer.filterValues { it.isNotBlank() },
                ).filterValues { it.isNotEmpty() }
                val height = e.heightText.toIntOrNull()?.takeIf { it > 0 }
                val scientific = e.scientificName.trim().takeIf { it.isNotEmpty() }
                val oldPrice = e.oldPriceText.toIntOrNull()?.takeIf { it > 0 }
                val pieces = e.piecesText.toIntOrNull()?.takeIf { it > 0 }
                val collection = e.collection.trim().takeIf { it.isNotEmpty() }
                val options = e.options.mapNotNull { draft ->
                    val values = draft.valuesText.split(',', '،').map { it.trim() }.filter { it.isNotEmpty() }.distinct()
                    if (draft.name.isBlank() || values.isEmpty()) null else ListingOption(draft.name.trim(), values)
                }

                if (e.listingId == null) {
                    repo.createListing(
                        NewListing(
                            sellerId = shop.id, section = e.section, category = e.category, occasions = e.occasions,
                            plantKey = e.plantKey, name = name, scientificName = scientific,
                            description = description, care = care, heightCm = height, priceIqd = price,
                            oldPriceIqd = oldPrice, pieces = pieces, options = options, collection = collection,
                            imagePath = imagePath, inStock = e.inStock, aiGenerated = e.aiGenerated,
                        )
                    )
                } else {
                    repo.updateListing(
                        e.listingId,
                        ListingUpdate(
                            section = e.section, category = e.category, occasions = e.occasions,
                            plantKey = e.plantKey, name = name, scientificName = scientific,
                            description = description, care = care, heightCm = height, priceIqd = price,
                            oldPriceIqd = oldPrice, pieces = pieces, options = options, collection = collection,
                            imagePath = imagePath, inStock = e.inStock, aiGenerated = e.aiGenerated,
                        )
                    )
                }
                reloadListings()
                _state.update { it.copy(editor = null) }
            } catch (_: Exception) {
                editor { it.copy(saving = false, error = EditorError.SaveFailed) }
            }
        }
    }

    // -------------------------------------------------------------------- shop

    fun saveShop(update: ShopUpdate) {
        val shop = _state.value.shop ?: return
        _state.update { it.copy(savingShop = true) }
        viewModelScope.launch {
            try {
                repo.updateShop(shop.id, update)
                val fresh = repo.fetchShop(profile.id)
                _state.update { it.copy(savingShop = false, shop = fresh ?: it.shop, overlay = null) }
            } catch (_: Exception) {
                _state.update { it.copy(savingShop = false) }
            }
        }
    }
}
