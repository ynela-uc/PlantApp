package com.plantapp.data

import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order

class ListingsRepository {
    /** All listings with their shop attached, newest first. */
    suspend fun fetchAll(): List<Listing> =
        Backend.client.from("listings")
            .select(Columns.raw("*, sellers(id,name,city,delivery_scope,delivers_to,rating,phone,bio,delivery_fee_iqd,delivery_fees,shop_types)")) {
                order("created_at", Order.DESCENDING)
            }
            .decodeList<Listing>()
}
