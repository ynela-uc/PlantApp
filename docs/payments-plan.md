# Card-only payments: research and plan (2026-10-21)

Decision by the owner: no cash on delivery, **card / online payment only from launch**. The app holds the customer's money and
pays the shop after delivery. A company has to be registered first.

This is research from public pages, not legal or financial advice. Every provider detail below must be confirmed with the provider.

## Options found for Iraq

| Provider | What the public pages say | Open questions |
|---|---|---|
| **FIB** (First Iraqi Bank), https://fib.iq/developers/web-payment | Public developer docs. Sandbox first, then an "Integration Request Form" for production credentials. OAuth2 client credentials, create / check status / cancel payment, callback URL, QR code and deep links into the FIB app, **IQD only**. | No refund endpoint described. Settlement time, fees and limits not on the page. Customers need the FIB app. |
| **ZainCash** (Zain Iraq wallet), docs at https://docs.zaincash.iq | Wallet payments: redirect, customer confirms with wallet number and OTP, signed token back, then check the final status through an inquiry API. Plugins exist. | Docs not read; refunds, settlement, fees, merchant requirements unknown. Customers need a ZainCash wallet. |
| **Qi Card** (the big Iraqi card issuer) | No public merchant API found. A third-party gateway (SindiPay) says it accepts all Iraqi bank cards including Qi Card. | Ask Qi directly whether a merchant gateway exists. |
| **PayTabs Iraq** (with local partner Amwal) | Card gateway with direct API, mobile SDK and iFrame. | Merchant reports say approval can be slow (NDA, weeks). Fees and settlement unknown. |
| Stripe, PayPal | Reported (by users) not to support Iraq. | Do not plan on them. |

Most Iraqi shoppers pay with different wallets and cards, so a single provider will miss some customers. Two ways to handle that:
build on one provider first, with the payment code written so a second provider can be added, or use a gateway that accepts several
(such as SindiPay), at the price of a middleman fee.

## Things that decide the choice (ask every provider)
1. What documents are needed for a merchant account (company registration, licences, bank account)? How long does approval take?
2. Is there a sandbox (test environment) we can use before approval?
3. Fees: per transaction, monthly, setup. In which currency and how fast do funds reach our bank account?
4. **Refunds:** is there a refund API, or are refunds manual? How long do they take?
5. **Marketplace payments:** can one payment be split between the platform and a shop, or paid out to several shops? (If not, the
   app receives everything and pays shops itself.)
6. Does the provider's licence allow a platform to collect money on behalf of other shops? What do they require from us?
7. How does a customer pay inside a mobile app (deep link to their wallet app, card form, redirect)?
8. Callbacks (webhooks) when a payment succeeds, fails or expires, and their security.

## Company
- Federal Iraq: reserve a name through the Chamber of Commerce, deposit the capital in an Iraqi bank, file with the Ministry of
  Trade's Registrar of Companies (memorandum of association, representative and agent resident in Iraq, documents in Arabic).
- Kurdistan Region: General Directorate of Companies Registration (Erbil, Sulaimani, Duhok); minimum 1,000,000 IQD capital, a
  statutory lawyer and accountant, a headquarters address; roughly 3 to 15 working days according to different pages.
- Use a local lawyer. Decide first where the company is based (Baghdad or Kurdistan), because it decides the office.

## The legal question to ask the lawyer before anything else
Holding customers' money and paying it out to shops later may count as a **payment service** regulated by the Central Bank of Iraq
(Electronic Payment Regulation No. 3 of 2014 and later instructions; licences are required and strictly scoped). It is not clear from
public sources whether a marketplace that collects on behalf of shops needs its own licence or can work under the payment
provider's licence. This must be answered by a lawyer before launch; it shapes the whole money flow.

## How the app will work once the provider is chosen (plan)
- Checkout ends in a payment. The order is created as **awaiting payment**, the shop is told only once it is **paid**; unpaid orders
  expire after about 15 minutes.
- Cash on delivery is removed from the apps and from the server (orders must be paid).
- The platform holds the money. A payout record per order is created when the order is **delivered**; shops are paid out on a
  schedule (for example the next business day) minus any commission, with a report for the owner.
- Every cancel rule gets a refund step: cancelled by the customer, declined or expired by the shop, failed delivery. Refunds are
  automatic when the provider has a refund API, otherwise listed for the owner to refund by hand.
- Terms and privacy policy must describe payments, refunds and payouts.

## Sources
- FIB developer docs: https://fib.iq/developers/web-payment
- ZainCash docs: https://docs.zaincash.iq
- PayTabs Iraq: https://site.paytabs.com/en/iraq-payment-gateway
- Electronic payment regulation in Iraq (law firm notes): https://www.tamimi.com/law-update-articles/technological-innovation-within-the-legal-sector-an-update-on-the-regulatory-framework-for-electronic-payment-services-in-iraq/
- Company registration: https://globallawexperts.com/company-registration-process-in-iraq-2026/ and https://services.gov.krd/en/node/104
