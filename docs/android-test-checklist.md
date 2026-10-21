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

- [ ] Customer -> My account tab -> "Edit my details": change the name, phone, governorate (19 governorates, including Halabja) and address, Save. The account page shows the new details, and the next order uses them.

## 9. Smart Assistant (the "Assistant" tab for customers)
- [ ] Customer -> Assistant tab (check the intro explains what it can do, and the three example chips work): take a photo of a real plant. A few seconds later you get: the plant's name (in the app language), scientific name, a health tag, short care advice, and 2-3 suggested follow-up questions.
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

## 11. Delivery fee, packages, discounts, shop pages (shops like Whites & Wicks)
- [ ] Seller -> Shop tab -> Edit: set the delivery fee (for example 5000) and a different fee for one city (for example Erbil 4000). Save. The Shop tab shows the fee.
- [ ] Seller -> add a product: fill price 27000, "price before discount" 33000, number of pieces 9, collection "Autumn 2026", and add a choice "Colour" with "Blue, Black". Save.
- [ ] Customer -> open that product: you see the price, the old price crossed out with "18% off", "9 pieces", the Colour choices, and a box with "Delivery to <your city>" and "Total with delivery". Tap Add to cart without choosing a colour: it asks you to choose.
- [ ] Choose Blue, add to cart, then choose Black and add again: the cart has two separate lines. The cart shows the delivery fee per shop and "Total with delivery".
- [ ] Checkout: change the delivery city: the delivery fee and total change (Erbil should use its own fee). Place the order.
- [ ] Order details (customer and seller): each line shows its choice (Blue), the delivery fee row, and the total. The seller's "collect in cash" amount includes delivery.
- [ ] On the product page tap "Visit the shop": the shop page shows its name, types, delivery fee, and Collections chips; tapping "Autumn 2026" shows only those products.

## 12. Colours and logo
- [ ] The app icon on the home screen is a teal square with a white gift tag (coral hole, teal leaf inside), not the old green icon.
- [ ] The welcome screen shows the same logo at the top, on a warm sand background (no green tint anywhere).
- [ ] On the entry screen the three sections have their own colour: Flowers coral, Plants green, Gifts gold; buttons and the tab bar are teal.
- [ ] Seller screens still use the amber colour for the seller badge; nothing is hard to read (white text on teal, dark teal text on sand).

## 13. Photo approval is optional now
- [ ] Seller -> edit a product: a "Photo before delivery" choice with three options (Not needed / If the customer asks / Always). New products are "Not needed".
- [ ] Customer orders a product set to "Not needed": no photo section at checkout. Seller accepts the order and taps "Out for delivery" straight away (no camera step). The customer's order page shows only Placed, Preparing, Out for delivery, Delivered.
- [ ] Product set to "If the customer asks": checkout shows "I want to see a photo before delivery". Untick it: no photo step. Tick it: the seller must send a photo and the customer must approve it.
- [ ] Product set to "Always": checkout says the shop will send a photo (no checkbox). The customer sees "If you do not answer within 60 minutes, the shop will continue" under the photo.
- [ ] After a photo is sent, the seller sees "Waiting for the customer"; after 60 minutes the text changes and a "Continue (no answer after 60 minutes)" button appears.

## 14. New-order alerts
- [ ] Seller phone: sign in, allow notifications, leave the app (Home button). A customer places an order: the phone shows a "طلب جديد" notification with a sound. Tapping it opens the app.
- [ ] Seller phone with the app OPEN (any screen, even the product editor): a customer places an order. Within 30 seconds an amber banner appears at the top ("New order from ..."), with a sound and vibration. Tapping it opens that order. It disappears by itself after about 12 seconds.
- [ ] The same new order does not ring twice (no system notification while the app is open).
- [ ] Leave a new order unopened for 10 minutes: one reminder notification arrives ("An order is waiting").
- [ ] Customer phone: when the shop sends the photo, a "Your order photo is ready" notification arrives; when the order goes out for delivery, "Your order is on its way".

## 15. Shop approval
- [ ] Create a NEW seller account and shop. The shop owner sees an amber notice at the top: "Your shop is waiting for approval". They can still add products.
- [ ] A customer account does NOT see that shop or its products anywhere (home, search, assistant).
- [ ] The admin's phone gets a push: "A new shop is waiting for approval" with the shop name.
- [ ] In Supabase -> Table Editor -> sellers, tick `approved` for the new shop. Within about 30 seconds the notice disappears on the owner's phone (the owner also gets a push "Your shop was approved"), and customers now see the shop.
- [ ] The existing shops (your test shop and the five demo shops) are still visible to customers.

## 16. Cancel and problem rules
- [ ] Customer: a NEW order (not accepted yet) shows a "Cancel order" button. Tap it, confirm: the order becomes Cancelled with "Reason: Cancelled by the customer", and the shop gets a "The customer cancelled" notification.
- [ ] Customer: once the shop has accepted, the Cancel button is gone.
- [ ] Shop: a new order shows "The customer's phone number appears after you accept the order." and no call button. After Accept, the phone and the Call button appear.
- [ ] Shop: Decline (new order) or Cancel order (accepted, waiting for photo, approved) asks "Why?" with four reasons. The customer sees the chosen reason on the cancelled order and gets a notification.
- [ ] Shop: on an order that is out for delivery there is a "Couldn't deliver" button with reasons (customer did not answer / refused / wrong address / other). The customer sees the reason.
- [ ] An order nobody answers for 12 hours is cancelled by itself ("The shop did not answer in time") and the customer is notified. (Test by changing created_at in the SQL editor to 13 hours ago and waiting up to 10 minutes.)

## 17. Call and WhatsApp
- [ ] Customer: open an order. A "Contact the shop" box has Call and WhatsApp buttons. Call opens the phone dialler with the shop's number. WhatsApp opens a chat with the shop with a ready message ("Hello, I'm asking about my order #XXXXXX").
- [ ] Customer: a shop's page also shows Call and WhatsApp.
- [ ] Shop: after accepting an order, the customer's phone row has Call and WhatsApp (message mentions the order number and the shop). Before accepting, no phone is shown.
- [ ] A number written as 0770 123 4567 opens WhatsApp as +964 770 123 4567.

## 18. Legal links and account deletion
- [ ] Sign-up screen: under the Create account button there is "By creating an account you agree to the Terms of Use and the Privacy Policy" with two links (they open in the browser once GitHub Pages is on).
- [ ] My account (customer) and Shop (shop owner): the links "Privacy policy" and "Terms of use", and a red "Delete my account" button.
- [ ] Delete my account asks to confirm. With an order in progress (preparing, waiting for photo, approved, out for delivery) it says "You still have orders in progress...". Otherwise the account is deleted and the app returns to the welcome screen; signing in again with that email fails.
- [ ] After a customer deletes their account, their old orders still appear for the shop but without name, phone and address.
- [ ] After a shop owner deletes their account, customers no longer see the shop or its products, and old orders stay.

## 19. Ratings
- [ ] Customer: open a DELIVERED order. A box "How was your order?" has five tappable stars, a comment field (max 300 characters) and "Send rating". Send stays disabled until a star is chosen.
- [ ] After sending, the box changes to "Your rating" with the stars and comment, and cannot be sent twice.
- [ ] An order that is not delivered shows no rating box.
- [ ] Shop page: shows "New" until the shop has 3 ratings, then "★ 4.7 (3)". The page ends with a "Reviews" list (latest 10) with stars, first name + last initial, date and comment; "No reviews yet" when empty.
- [ ] The product page shows the same "New" / stars label next to the city.
- [ ] When a shop marks an order delivered the customer gets a push "Your order was delivered / How was your order from <shop>? Rate it now".
- [ ] Shop owner: cannot change their own rating (the shop screen has no such field).
- [ ] Customer deletes their account: their reviews stay but show "Customer" instead of the name.

## Report
For anything that fails: which step, what you tapped, what the screen said (a screenshot is best).
