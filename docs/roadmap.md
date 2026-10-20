# Roadmap and ideas (kept so nothing is forgotten)

Last updated 2026-10-20. Order inside each group is the order we suggest, not a promise.

## Ideas to build later (from the owner)
1. **Return system.** Customers can report a problem or ask for a return after delivery.
2. **Real ratings by customers.** Stars and a short comment from people who actually received an order.
3. **Follow a seller.** Customers follow shops they like and see their new products.

Notes and suggested shape (a starting point, to decide together before building):

### 1. Returns
- Flowers and live plants are perishable, so no "return" in the normal sense. A **problem report** within about 24 hours
  of delivery, with a photo, and the shop decides: replace, partial refund, or reject. Gifts and decor can allow a
  return of unused items within 1 to 2 days. The rules should be written per section and shown before ordering.
- The existing photo approval step (the customer approves the shop's photo before delivery) already prevents many
  disputes; the report screen should show that photo next to the delivery complaint.
- Needs: a `returns` table (order, reason, photos, status, shop reply), a screen for the customer, a screen for the shop,
  notifications to both sides, and a way for the owner to see disputes. Refunds are manual at first (cash on delivery).
- Open question: who pays the delivery of a return.

### 2. Ratings
- Only the buyer of a **delivered** order can rate it, once per order. Stars plus an optional comment; the shop can reply.
- The shop's stars are then calculated from these ratings. Today `sellers.rating` is just the seed value, so it must be
  replaced by the real average (and hidden until a shop has a few ratings).
- Ask for the rating when the order is marked delivered (needs notifications). Add a way to report an abusive comment.
- Start with the shop rating per order; product-level ratings later, if needed.

### 3. Follow a seller
- A follow button on the shop page, a follower count, and a "from shops you follow" list on the home screen.
- Optional push when a followed shop adds a product or starts a collection (needs the notification system, so build
  seller order alerts first and reuse it). Good fit for Instagram-style shops like Whites & Wicks.
- Needs: a `follows` table (customer, shop) with row-level security, plus a limit so shops cannot spam followers.

## Next up
- **Order alerts (planned together, in progress).** Push notifications so a shop knows at once about a new order, and a
  customer knows when the photo is ready for approval or the order is on its way. Also the base for follow and ratings.

## Must-have before real customers
- Seller order alerts (above).
- Seller approval: the owner can approve or block shops before customers see them (check what exists).
- Cancel and problem rules: what happens when a customer cancels or a shop rejects an order.
- Privacy policy and terms (the stores require them).
- Real data: demo flower and gift products, and a real trial with Whites & Wicks.

## Important, not day one
- Call or WhatsApp button to reach the shop; favorites and better search; stock levels; more than one photo per product;
  saved delivery addresses.

## Later
- Online payment (Ki Card, FIB), "build your own package", Kurdish wording review by a Sorani speaker, final app name and logo,
  Google Play and Apple release (Apple Developer account is needed for iPhone push and TestFlight).

## Done recently
- Server-side order checking (migration 013): the database recomputes prices, delivery fee and total.
- Categories cleaned up (migration 012), Smart Assistant renamed, "Ask" tab, brand theme and logo.
