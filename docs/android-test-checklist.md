# PlantApp test checklist (Android, real backend)

The iPhone and Android apps share one Supabase backend, so a full run on Android proves the
backend. Use two phones or two emulator windows if you can: one for the customer, one for the
seller. One device works too: sign out and in between steps.

**Accounts:** create fresh ones inside the app (email confirmation is off). Use real-looking
emails such as `plantapp.buyer2@gmail.com` and `plantapp.seller2@gmail.com`; `example.com` is
blocked. Password: at least 6 characters.

Tick each line. Write down what you saw if it is not what is expected.

## 1. Welcome and languages
- [ ] Welcome screen shows Customer and Seller cards.
- [ ] Language picker (bottom) switches Arabic / Kurdish / English at once; Arabic and Kurdish flip the layout right-to-left.

## 2. Seller: create the shop
- [ ] Choose Seller -> Create account (name, phone, email, password, shop name, city).
- [ ] You land in the seller app (Orders / My plants / Shop tabs).
- [ ] Shop tab shows the right shop name and city. Edit the shop: set phone, choose Local (pick cities) or Nationwide, save.

## 3. Seller: add a plant with the AI camera
- [ ] My plants -> Add a plant -> take a photo of a real plant (or pick one from the gallery).
- [ ] The AI fills the name, description, care tips, and height in all three languages; you only type the price.
- [ ] Change one field by hand, save. The plant appears in the list with its photo.
- [ ] Toggle "in stock" off and on. Edit the plant, then (last) delete a second test plant to check delete.
- [ ] Take a photo of something that is not a plant: the app should say it could not see a plant and let you type.

## 4. Customer: browse and order
- [ ] Choose Customer -> Create account (name, phone, email, password, city, address).
- [ ] Browse shows the seller's plant (the plant's photo, price, "local"/"nationwide" badge). Search works. Picking a different city hides shops that do not deliver there.
- [ ] Open the plant: shop name, care tips, size. Add to cart twice, change quantity in the cart.
- [ ] Checkout: pay on delivery. Try both "for me" and "gift" (recipient name, phone, note). Pick a date and a time window. Place the order.
- [ ] "Order placed" page appears; the Orders tab shows it as Placed.

## 5. Seller: handle the order (order status steps)
- [ ] The order shows in the seller Orders tab with a "new" count and a highlighted card. Customer name, phone (call button), items, "collect X in cash".
- [ ] Accept order -> status Preparing.
- [ ] Take a photo of the prepared order and send it -> status "Photo sent".

## 6. Customer: approve the photo
- [ ] Order shows the seller's photo. First try "Request a change", write a note: the seller sees the note and status goes back to Preparing.
- [ ] Seller sends a new photo. Customer approves -> status Approved.

## 7. Delivery and end
- [ ] Seller: Out for delivery -> Mark as delivered. Customer sees Delivered with the full timeline.
- [ ] Place a second order and let the seller Decline it: customer sees Cancelled.

## 8. Account basics
- [ ] Sign out and in again (both accounts). Using the seller email on the Customer screen shows the "this is a seller account" message (and the other way round).
- [ ] Forgot password: request a reset email for a test account, open the link on the same phone, set a new password, you are signed in.
  (Needs a real inbox. Supabase's built-in email is rate limited, so try this at most a few times.)

## 9. Plant helper (the "Plant help" tab for customers)
- [ ] Customer -> Plant help tab: take a photo of a real plant. A few seconds later you get: the plant's name (in the app language), scientific name, a health tag, short care advice, and 2-3 suggested follow-up questions.
- [ ] A shop that sells that plant (add one as the seller first) appears under "Where to buy": shops in your city first, then shops that deliver to you, then other cities. Tap one: the plant page opens.
- [ ] Take a photo of a sick plant (yellow or brown leaves): the health tag says "Needs attention" or "Unhealthy" and the answer says what to do.
- [ ] Type a question ("how often do I water it?") or tap a suggested question: you get an answer about the same plant.
- [ ] Photo of something that is not a plant: the helper says it cannot see a plant and asks for a clearer photo.
- [ ] Switch the language to Arabic and Kurdish and ask again: the answer comes back in that language.
- [ ] "New chat" clears the conversation.
- Limits (per person, per day): 12 photos and 40 messages. After that the app shows a "limit reached" message.

## 10. Sections, categories and the entry screen
- [ ] Close the app completely and open it as a customer: the first screen asks "What are you looking for?" with Flowers, Plants and Gifts & decor, plus occasions and "All products". It appears every time the app starts.
- [ ] Tap Plants: the existing plants appear, with category chips (Indoor plants, Succulents & cacti, Soil, Fertilizers, Pots, Tools ...). Tap a chip to filter. "Home" goes back to the three tiles.
- [ ] Tap an occasion (e.g. Birthday): only products the shop tagged with that occasion appear.
- [ ] Seller: create a NEW seller account: you must pick at least one shop type (flowers, plants, gifts). Shop tab shows the types; edit them.
- [ ] Seller: Add a product -> choose Section and Category (required) and optional occasions. For Flowers or Gifts the plant-only fields (scientific name, water, light, height) disappear.
- [ ] Seller: photograph a candle, a bouquet or a pot with the AI button: the AI picks the section and category and fills the name and description in three languages.
- [ ] The new product shows up for customers under its section and category.

## Report
For anything that fails: which step, what you tapped, what the screen said (a screenshot is best).
