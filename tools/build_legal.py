#!/usr/bin/env python3
"""
Builds the public privacy policy and terms pages (docs/legal/*.html) in English, Arabic and Kurdish (Sorani).
Edit the text below, then run:  python tools/build_legal.py

Placeholders to replace before publishing (search for the square brackets): company name, email, phone, address, court city.
They live in PLACEHOLDERS so one edit changes every page.
"""
from pathlib import Path
from html import escape

OUT = Path(__file__).resolve().parents[1] / "docs" / "legal"
UPDATED = "2026-10-21"

# Replace these when the company exists (they appear in every page).
PLACEHOLDERS = {
    "en": {"company": "[COMPANY NAME]", "email": "[CONTACT EMAIL]", "phone": "[CONTACT PHONE]", "address": "[COMPANY ADDRESS]", "court": "[CITY]"},
    "ar": {"company": "[اسم الشركة]", "email": "[البريد الإلكتروني للتواصل]", "phone": "[رقم الهاتف]", "address": "[عنوان الشركة]", "court": "[المدينة]"},
    "ckb": {"company": "[ناوی کۆمپانیا]", "email": "[ئیمەیڵی پەیوەندی]", "phone": "[ژمارەی تەلەفۆن]", "address": "[ناونیشانی کۆمپانیا]", "court": "[شار]"},
}
APP = {"en": "PlantApp", "ar": "PlantApp", "ckb": "PlantApp"}  # the app name: change when it is final

LANGS = {
    "en": {"name": "English", "dir": "ltr", "title_privacy": "Privacy Policy", "title_terms": "Terms of Use", "updated": "Last updated", "other": "Other languages"},
    "ar": {"name": "العربية", "dir": "rtl", "title_privacy": "سياسة الخصوصية", "title_terms": "شروط الاستخدام", "updated": "آخر تحديث", "other": "لغات أخرى"},
    "ckb": {"name": "کوردی", "dir": "rtl", "title_privacy": "سیاسەتی نهێنیێتی", "title_terms": "مەرجەکانی بەکارهێنان", "updated": "دوایین نوێکردنەوە", "other": "زمانەکانی تر"},
}

# Each section: (heading, [paragraphs or ("ul", [items])]). {company} {email} {phone} {address} {court} {app} are filled in.
PRIVACY = {
    "en": [
        ("Who we are", ["{app} is a marketplace app for flower shops, plant shops and gift shops in Iraq. It is operated by {company}, {address} (“we”). Contact: {email}, {phone}."]),
        ("What we collect", [("ul", [
            "Account details: your name, email, phone number, city and delivery address.",
            "For shops: the shop name, phone, description, delivery areas and fees, and the products you list with their photos and prices.",
            "Orders: what was ordered, the delivery address, the delivery date and time window, the gift recipient’s name, phone and note (if it is a gift), the order status, and the reason when an order is cancelled.",
            "Photos: the photo a shop sends so a customer can approve an order before delivery, and product photos.",
            "Smart Assistant: the questions you type and the photos you send are processed to give you an answer. We keep only a count of how many times a person used it per day, not the messages or photos.",
            "Your phone’s notification address (a token) and your language, so we can send order notifications.",
            "Basic technical information (such as error logs) needed to keep the service working."])]),
        ("How we use it", [("ul", [
            "To create your account and run orders from placing to delivery.",
            "To show shops to customers and orders to shops.",
            "To send notifications about orders (new order, photo ready, on its way, cancelled).",
            "To answer questions in the Smart Assistant.",
            "To prevent abuse and keep the service secure, and to meet legal duties."])]),
        ("Who can see your information", [
            "Shops see the name and delivery address of customers who order from them. A customer’s phone number is shown to the shop only after the shop accepts the order. Customers see a shop’s public details (name, city, phone, description, products).",
            "We use service providers to run the app: Supabase (database, sign-in and file storage), Google Firebase Cloud Messaging (notifications), and Anthropic (the AI behind the Smart Assistant and the photo helper that fills in product details). When online payment is added, a payment provider will also receive the data needed to take the payment. These providers handle data under their own terms.",
            "We do not sell your personal information."]),
        ("How long we keep it", ["We keep your information while your account exists. When you delete your account, your profile, shop details, products and notification addresses are removed. Past orders are kept for the shops’ and our records without your name, phone number and address."]),
        ("Your choices and rights", [("ul", [
            "You can see and edit your details in the app (My account / Shop).",
            "You can delete your account in the app: My account → Delete my account (shops: Shop → Delete my account).",
            "You can contact us at {email} to ask about, correct or delete your information."])]),
        ("Delete your account", ["Open the app, go to My account (shops: the Shop tab) and tap “Delete my account”. If you cannot use the app, write to {email} from the email address of your account and we will delete it."]),
        ("Children", ["The app is not meant for people under 18."]),
        ("Security", ["We use secure connections and access rules so people can only see what they should. No service can promise perfect security."]),
        ("Changes and contact", ["We may update this policy; the date at the top shows the latest version. Questions: {email}, {phone}."]),
    ],
    "ar": [
        ("من نحن", ["{app} تطبيق سوق للورود والنباتات والهدايا في العراق، تشغّله {company}، {address} («نحن»). للتواصل: {email}، {phone}."]),
        ("ما الذي نجمعه", [("ul", [
            "بيانات الحساب: الاسم والبريد الإلكتروني ورقم الهاتف والمحافظة وعنوان التوصيل.",
            "للمتاجر: اسم المتجر وهاتفه ووصفه ومناطق التوصيل ورسومه، والمنتجات التي تضيفها مع صورها وأسعارها.",
            "الطلبات: ما تم طلبه، وعنوان التوصيل، وتاريخ التوصيل ووقته، واسم مستلم الهدية ورقمه وملاحظتك (إن كان الطلب هدية)، وحالة الطلب، وسبب الإلغاء عند إلغاء الطلب.",
            "الصور: الصورة التي يرسلها المتجر لتوافق عليها قبل التوصيل، وصور المنتجات.",
            "المساعد الذكي: الأسئلة التي تكتبها والصور التي ترسلها تُعالَج لتعطيك الإجابة. نحتفظ فقط بعدد مرات الاستخدام اليومية لكل شخص، ولا نحتفظ بالرسائل ولا بالصور.",
            "عنوان الإشعارات في هاتفك (رمز) ولغتك، لنتمكن من إرسال إشعارات الطلبات.",
            "معلومات تقنية بسيطة (مثل سجلات الأخطاء) لازمة لإبقاء الخدمة تعمل."])]),
        ("كيف نستخدمها", [("ul", [
            "لإنشاء حسابك وإدارة الطلب من لحظة إرساله إلى التوصيل.",
            "لعرض المتاجر للزبائن وعرض الطلبات للمتاجر.",
            "لإرسال إشعارات الطلبات (طلب جديد، الصورة جاهزة، في الطريق، تم الإلغاء).",
            "للإجابة عن أسئلتك في المساعد الذكي.",
            "لمنع إساءة الاستخدام وحماية الخدمة والوفاء بالالتزامات القانونية."])]),
        ("من يستطيع رؤية معلوماتك", [
            "ترى المتاجر اسم الزبون وعنوان التوصيل للطلبات الموجّهة إليها. ولا يظهر رقم هاتف الزبون للمتجر إلا بعد أن يقبل المتجر الطلب. ويرى الزبائن البيانات العامة للمتجر (الاسم والمحافظة والهاتف والوصف والمنتجات).",
            "نستعين بمزوّدي خدمات لتشغيل التطبيق: Supabase (قاعدة البيانات وتسجيل الدخول وتخزين الملفات)، وGoogle Firebase Cloud Messaging (الإشعارات)، وAnthropic (الذكاء الاصطناعي خلف المساعد الذكي ومساعد الصور الذي يملأ بيانات المنتج). وعند إضافة الدفع الإلكتروني سيحصل مزوّد الدفع على البيانات اللازمة لإتمام الدفع. يتعامل هؤلاء المزوّدون مع البيانات وفق شروطهم الخاصة.",
            "نحن لا نبيع معلوماتك الشخصية."]),
        ("مدة الاحتفاظ بها", ["نحتفظ بمعلوماتك ما دام حسابك موجودًا. عند حذف حسابك تُحذف بياناتك الشخصية وبيانات المتجر والمنتجات وعناوين الإشعارات. وتبقى الطلبات السابقة في سجلات المتاجر وسجلاتنا من دون اسمك ورقم هاتفك وعنوانك."]),
        ("خياراتك وحقوقك", [("ul", [
            "يمكنك الاطلاع على بياناتك وتعديلها داخل التطبيق (حسابي / المتجر).",
            "يمكنك حذف حسابك من داخل التطبيق: حسابي ← حذف حسابي (للمتاجر: المتجر ← حذف حسابي).",
            "يمكنك مراسلتنا على {email} للسؤال عن معلوماتك أو تصحيحها أو حذفها."])]),
        ("حذف الحساب", ["افتح التطبيق وادخل إلى «حسابي» (للمتاجر: تبويب المتجر) واضغط «حذف حسابي». وإن لم تستطع استخدام التطبيق فراسلنا على {email} من البريد المسجّل في حسابك وسنحذفه."]),
        ("الأطفال", ["التطبيق غير موجّه لمن هم دون 18 سنة."]),
        ("الأمان", ["نستخدم اتصالات آمنة وقواعد وصول بحيث لا يرى الشخص إلا ما يحق له. ولا توجد خدمة تضمن الأمان المطلق."]),
        ("التغييرات والتواصل", ["قد نحدّث هذه السياسة، ويبيّن التاريخ في أعلى الصفحة آخر نسخة. للاستفسار: {email}، {phone}."]),
    ],
    "ckb": [
        ("ئێمە کێین", ["{app} ئەپی بازاڕە بۆ گوڵفرۆشی و ڕووەکفرۆشی و دیاری لە عێراق، {company} بەڕێوەی دەبات، {address} («ئێمە»). پەیوەندی: {email}، {phone}."]),
        ("چی کۆدەکەینەوە", [("ul", [
            "زانیاری ئەکاونت: ناو، ئیمەیڵ، ژمارەی تەلەفۆن، پارێزگا و ناونیشانی گەیاندن.",
            "بۆ فرۆشگاکان: ناوی فرۆشگا، تەلەفۆن، وەسف، ناوچەکانی گەیاندن و کرێکەی، و ئەو بەرهەمانەی زیادیان دەکەیت لەگەڵ وێنە و نرخەکانیان.",
            "داواکارییەکان: چی داواکراوە، ناونیشانی گەیاندن، ڕێکەوت و کاتی گەیاندن، ناو و ژمارە و تێبینی وەرگری دیاری (ئەگەر دیاری بێت)، دۆخی داواکاری، و هۆکاری هەڵوەشاندنەوە.",
            "وێنەکان: ئەو وێنەیەی فرۆشگا دەینێرێت تا پێش گەیاندن پەسەندی بکەیت، و وێنەی بەرهەمەکان.",
            "یاریدەدەری زیرەک: پرسیارەکانت و ئەو وێنانەی دەینێریت پرۆسێس دەکرێن بۆ وەڵامدانەوە. تەنها ژمارەی جارەکانی بەکارهێنانی ڕۆژانە هەڵدەگرین، نەک نامە و وێنەکان.",
            "ناونیشانی ئاگادارکردنەوەی تەلەفۆنەکەت (تۆکن) و زمانەکەت، بۆ ناردنی ئاگادارکردنەوەی داواکارییەکان.",
            "زانیاری تەکنیکی سادە (وەک تۆماری هەڵەکان) کە پێویستە بۆ کارکردنی خزمەتگوزارییەکە."])]),
        ("چۆن بەکاریان دەهێنین", [("ul", [
            "بۆ دروستکردنی ئەکاونتەکەت و بەڕێوەبردنی داواکاری لە ناردنەوە تا گەیاندن.",
            "بۆ پیشاندانی فرۆشگاکان بە کڕیاران و داواکارییەکان بە فرۆشگاکان.",
            "بۆ ناردنی ئاگادارکردنەوەی داواکارییەکان (داواکاری نوێ، وێنە ئامادەیە، لە ڕێگایە، هەڵوەشێندرایەوە).",
            "بۆ وەڵامدانەوەی پرسیارەکانت لە یاریدەدەری زیرەک.",
            "بۆ ڕێگریکردن لە خراپ بەکارهێنان و پاراستنی خزمەتگوزارییەکە و جێبەجێکردنی ئەرکە یاساییەکان."])]),
        ("کێ دەتوانێت زانیارییەکانت ببینێت", [
            "فرۆشگاکان ناو و ناونیشانی گەیاندنی ئەو کڕیارانە دەبینن کە لێیان داواکاری دەکەن. ژمارەی تەلەفۆنی کڕیار تەنها دوای قبوڵکردنی داواکارییەکە بۆ فرۆشگا دەردەکەوێت. کڕیاران زانیاری گشتی فرۆشگا دەبینن (ناو، پارێزگا، تەلەفۆن، وەسف، بەرهەمەکان).",
            "بۆ بەڕێوەبردنی ئەپەکە خزمەتگوزارییەکان بەکاردەهێنین: Supabase (داتابەیس، چوونەژوورەوە و هەڵگرتنی فایل)، Google Firebase Cloud Messaging (ئاگادارکردنەوە)، و Anthropic (زیرەکی دەستکرد لەپشت یاریدەدەری زیرەک و یاریدەدەری وێنە). کاتێک پارەدانی ئۆنلاین زیاد بکرێت، دابینکەری پارەدان ئەو زانیارییانە وەردەگرێت کە بۆ پارەدان پێویستە. ئەم دابینکەرانە بە مەرجی خۆیان مامەڵە لەگەڵ زانیاری دەکەن.",
            "ئێمە زانیاری کەسیت نافرۆشین."]),
        ("چەند ماوەیەک هەڵیدەگرین", ["تا ئەکاونتەکەت هەبێت زانیارییەکانت هەڵدەگرین. کاتێک ئەکاونتەکەت دەسڕیتەوە، زانیاری کەسی و فرۆشگا و بەرهەمەکان و ناونیشانی ئاگادارکردنەوە دەسڕێنەوە. داواکارییە پێشووەکان بۆ تۆماری فرۆشگاکان و ئێمە دەمێننەوە بەبێ ناو و ژمارەی تەلەفۆن و ناونیشانەکەت."]),
        ("هەڵبژاردن و مافەکانت", [("ul", [
            "دەتوانیت زانیارییەکانت لە ئەپەکەدا ببینیت و بیگۆڕیت (هەژمارەکەم / فرۆشگا).",
            "دەتوانیت ئەکاونتەکەت لە ناو ئەپەکە بسڕیتەوە: هەژمارەکەم ← سڕینەوەی ئەکاونتەکەم (فرۆشگاکان: فرۆشگا ← سڕینەوەی ئەکاونتەکەم).",
            "دەتوانیت پەیوەندیمان پێوە بکەیت لە {email} بۆ پرسیار یان ڕاستکردنەوە یان سڕینەوەی زانیارییەکانت."])]),
        ("سڕینەوەی ئەکاونت", ["ئەپەکە بکەرەوە، بچۆ بۆ «هەژمارەکەم» (فرۆشگاکان: تابی فرۆشگا) و کلیک لە «سڕینەوەی ئەکاونتەکەم» بکە. ئەگەر نەتتوانی ئەپەکە بەکاربهێنیت، لە ئیمەیڵی ئەکاونتەکەتەوە بۆ {email} بنووسە و دەیسڕینەوە."]),
        ("منداڵان", ["ئەپەکە بۆ کەسانی خوار ١٨ ساڵ نییە."]),
        ("پاراستن", ["پەیوەندی پارێزراو و یاسای دەستگەیشتن بەکاردەهێنین تا هەر کەسێک تەنها ئەوە ببینێت کە مافیەتی. هیچ خزمەتگوزارییەک پاراستنی تەواو بەڵێن نادات."]),
        ("گۆڕانکاری و پەیوەندی", ["لەوانەیە ئەم سیاسەتە نوێ بکەینەوە؛ ڕێکەوتی سەرەوە دوایین وەشان پیشان دەدات. پرسیار: {email}، {phone}."]),
    ],
}

TERMS = {
    "en": [
        ("About these terms", ["These terms apply when you use {app}, operated by {company} (“we”). By creating an account or using the app you agree to them and to the Privacy Policy. You must be at least 18."]),
        ("What the app is", ["{app} connects customers with independent flower, plant and gift shops. The shops sell and deliver the products; we provide the app. The shop, not us, is responsible for its products, prices, preparation and delivery, unless we say otherwise in writing."]),
        ("Accounts", [("ul", [
            "Give correct information and keep your password private. One person, one account.",
            "Shops must be approved by us before customers can see them. We may refuse, hide or suspend a shop or an account that breaks these terms or harms customers.",
            "You can delete your account at any time in the app."])]),
        ("Orders", [("ul", [
            "An order is a request to a shop. It becomes an agreement when the shop accepts it.",
            "A customer can cancel an order until the shop accepts it. After that, only the shop can cancel; contact the shop through the app’s call or WhatsApp buttons if you need a change.",
            "A shop that declines or cancels an order must give a reason, which the customer sees. If a shop does not answer within 12 hours, the order is cancelled automatically.",
            "If a delivery fails (for example nobody answers or the address is wrong), the shop records the reason and closes the order.",
            "For some products a shop sends a photo before delivery. The customer approves it or asks for a change. If the customer does not answer within 60 minutes, the shop may continue."])]),
        ("Prices and payment", ["Prices are in Iraqi dinars and shown before you order, including the shop’s delivery fee. Payment methods are shown at checkout. How payments, refunds and payouts to shops work will be described here when online payment is enabled."]),
        ("Living products", ["Plants and flowers are natural and perishable. Photos are for guidance and the real product may differ slightly. If something arrives damaged or wrong, contact the shop first; we may help resolve it."]),
        ("Rules for shops", [("ul", [
            "List accurate products, photos and prices, and keep stock status up to date.",
            "Deliver what you accepted, or cancel with an honest reason.",
            "Use a customer’s name, phone and address only to complete that order.",
            "Do not ask customers to cancel an order in the app so you can sell to them outside the app, and do not take the sale elsewhere.",
            "Do not sell illegal, dangerous or misleading products."])]),
        ("Rules for customers", ["Do not place false orders, abuse shops or delivery staff, or misuse the app."]),
        ("Smart Assistant", ["The Smart Assistant gives general information about plants, flowers and gifts and can be wrong. It is not professional advice. Check important decisions (for example treating a sick plant, or anything involving chemicals, children or pets) with an expert."]),
        ("Content", ["Shops keep ownership of the photos and text they upload and allow us to show them in the app. The app, its design and code belong to us or our licensors."]),
        ("Our responsibility", ["We work to keep the app available and correct but cannot promise it will always be error-free or uninterrupted. To the extent the law allows, we are not responsible for the conduct of shops or customers, or for indirect losses."]),
        ("Law and disputes", ["These terms are governed by the laws of Iraq. Disputes go to the competent courts of {court}."]),
        ("Changes and contact", ["We may update these terms; continuing to use the app after a change means you accept it. Contact: {email}, {phone}."]),
    ],
    "ar": [
        ("عن هذه الشروط", ["تسري هذه الشروط عند استخدامك {app}، الذي تشغّله {company} («نحن»). بإنشاء حساب أو باستخدام التطبيق فإنك توافق عليها وعلى سياسة الخصوصية. يجب ألا يقل عمرك عن 18 سنة."]),
        ("ما هو التطبيق", ["{app} يربط الزبائن بمتاجر مستقلة للورود والنباتات والهدايا. المتاجر هي التي تبيع وتوصّل المنتجات، ونحن نوفّر التطبيق. والمتجر، لا نحن، هو المسؤول عن منتجاته وأسعاره وتجهيزه وتوصيله، ما لم نذكر خلاف ذلك كتابةً."]),
        ("الحسابات", [("ul", [
            "قدّم معلومات صحيحة وحافظ على سرّية كلمة المرور. لكل شخص حساب واحد.",
            "يجب أن نوافق على المتجر قبل أن يراه الزبائن. ويجوز لنا رفض أي متجر أو حساب يخالف هذه الشروط أو يضرّ بالزبائن أو إخفاؤه أو إيقافه.",
            "يمكنك حذف حسابك في أي وقت من داخل التطبيق."])]),
        ("الطلبات", [("ul", [
            "الطلب هو طلب موجَّه إلى متجر، ويصبح اتفاقًا حين يقبله المتجر.",
            "يستطيع الزبون إلغاء الطلب إلى أن يقبله المتجر. بعد ذلك يستطيع المتجر وحده الإلغاء؛ وإن أردت تعديلًا فتواصل مع المتجر عبر زرّي الاتصال والواتساب في التطبيق.",
            "على المتجر الذي يرفض الطلب أو يلغيه أن يذكر سببًا يراه الزبون. وإذا لم يردّ المتجر خلال 12 ساعة يُلغى الطلب تلقائيًا.",
            "إذا تعذّر التوصيل (مثل عدم ردّ أحد أو خطأ العنوان) يسجّل المتجر السبب ويُغلق الطلب.",
            "في بعض المنتجات يرسل المتجر صورة قبل التوصيل ليوافق عليها الزبون أو يطلب تعديلها. وإذا لم يردّ الزبون خلال 60 دقيقة يجوز للمتجر المتابعة."])]),
        ("الأسعار والدفع", ["الأسعار بالدينار العراقي وتظهر قبل الطلب شاملةً رسوم توصيل المتجر. وتظهر طرق الدفع عند إتمام الطلب. وسيُشرح هنا كيف يعمل الدفع والاسترداد وتحويل المبالغ للمتاجر عند تفعيل الدفع الإلكتروني."]),
        ("منتجات حيّة", ["النباتات والورود طبيعية وسريعة التلف. والصور للاسترشاد وقد يختلف المنتج الفعلي قليلًا. وإذا وصل شيء تالفًا أو خاطئًا فتواصل مع المتجر أولًا، وقد نساعد في حلّ المشكلة."]),
        ("قواعد المتاجر", [("ul", [
            "اعرض منتجات وصورًا وأسعارًا دقيقة، وحدّث حالة التوفر.",
            "سلّم ما قبلته أو ألغِ بسبب صادق.",
            "استخدم اسم الزبون وهاتفه وعنوانه لإتمام ذلك الطلب فقط.",
            "لا تطلب من الزبون إلغاء الطلب في التطبيق لتبيعه خارج التطبيق، ولا تنقل البيع إلى مكان آخر.",
            "لا تبع منتجات غير قانونية أو خطرة أو مضلِّلة."])]),
        ("قواعد الزبائن", ["لا تقدّم طلبات وهمية، ولا تسيء إلى المتاجر أو عمّال التوصيل، ولا تسيء استخدام التطبيق."]),
        ("المساعد الذكي", ["يقدّم المساعد الذكي معلومات عامة عن النباتات والورود والهدايا وقد يخطئ. وهو ليس نصيحة مهنية. استشر مختصًا في القرارات المهمة (مثل علاج نبتة مريضة أو أي أمر يتعلق بمواد كيميائية أو أطفال أو حيوانات أليفة)."]),
        ("المحتوى", ["تحتفظ المتاجر بملكية الصور والنصوص التي ترفعها وتسمح لنا بعرضها في التطبيق. والتطبيق وتصميمه وبرمجته ملك لنا أو لمرخّصينا."]),
        ("مسؤوليتنا", ["نعمل على إبقاء التطبيق متاحًا وصحيحًا، لكن لا نستطيع الوعد بأنه سيكون دائمًا بلا أخطاء أو انقطاع. وبالقدر الذي يسمح به القانون لا نتحمل مسؤولية تصرفات المتاجر أو الزبائن ولا الخسائر غير المباشرة."]),
        ("القانون والنزاعات", ["تخضع هذه الشروط لقوانين جمهورية العراق، وتُحال النزاعات إلى المحاكم المختصة في {court}."]),
        ("التغييرات والتواصل", ["قد نحدّث هذه الشروط، واستمرارك في استخدام التطبيق بعد التغيير يعني قبولك له. للتواصل: {email}، {phone}."]),
    ],
    "ckb": [
        ("دەربارەی ئەم مەرجانە", ["ئەم مەرجانە کاتێک جێبەجێ دەبن کە {app} بەکاردەهێنیت، کە {company} بەڕێوەی دەبات («ئێمە»). بە دروستکردنی ئەکاونت یان بەکارهێنانی ئەپەکە ڕازی دەبیت پێیان و بە سیاسەتی نهێنیێتی. دەبێت تەمەنت لانی کەم ١٨ ساڵ بێت."]),
        ("ئەپەکە چییە", ["{app} کڕیاران بە فرۆشگای سەربەخۆی گوڵ و ڕووەک و دیاریەوە دەبەستێتەوە. فرۆشگاکان بەرهەمەکان دەفرۆشن و دەیگەیەنن، ئێمە ئەپەکە دابین دەکەین. فرۆشگا، نەک ئێمە، بەرپرسە لە بەرهەم و نرخ و ئامادەکردن و گەیاندن، مەگەر بە نووسین شتێکی تر بڵێین."]),
        ("ئەکاونتەکان", [("ul", [
            "زانیاری ڕاست بدە و وشەی نهێنی بپارێزە. هەر کەسێک یەک ئەکاونت.",
            "دەبێت ئێمە پەسەندی فرۆشگا بکەین پێش ئەوەی کڕیاران ببینن. دەتوانین فرۆشگا یان ئەکاونتێک ڕەت بکەینەوە یان بیشارینەوە یان ڕایبگرین ئەگەر ئەم مەرجانە بشکێنێت یان زیان بە کڕیاران بگەیەنێت.",
            "دەتوانیت لە هەر کاتێکدا ئەکاونتەکەت لە ناو ئەپەکە بسڕیتەوە."])]),
        ("داواکارییەکان", [("ul", [
            "داواکاری داواکارییەکە بۆ فرۆشگا. کاتێک فرۆشگا قبوڵی دەکات دەبێتە ڕێککەوتن.",
            "کڕیار دەتوانێت داواکاری هەڵبوەشێنێتەوە تا فرۆشگا قبوڵی دەکات. دوای ئەوە تەنها فرۆشگا دەتوانێت هەڵیبوەشێنێتەوە؛ ئەگەر گۆڕانکاریت دەوێت لە ڕێگەی دوگمەکانی پەیوەندی و واتسئاپی ئەپەکەوە پەیوەندی بە فرۆشگاکە بکە.",
            "فرۆشگایەک کە داواکاری ڕەت دەکاتەوە یان هەڵیدەوەشێنێتەوە دەبێت هۆکار بدات کە کڕیار دەیبینێت. ئەگەر فرۆشگا لە ماوەی ١٢ کاتژمێردا وەڵام نەداتەوە داواکارییەکە خۆکارانە هەڵدەوەشێتەوە.",
            "ئەگەر گەیاندن سەرنەکەوت (وەک کەس وەڵام نەداتەوە یان ناونیشان هەڵە بێت) فرۆشگا هۆکارەکە تۆمار دەکات و داواکارییەکە دادەخات.",
            "بۆ هەندێک بەرهەم فرۆشگا پێش گەیاندن وێنەیەک دەنێرێت تا کڕیار پەسەندی بکات یان گۆڕانکاری داوا بکات. ئەگەر کڕیار لە ماوەی ٦٠ خولەکدا وەڵام نەداتەوە فرۆشگا دەتوانێت بەردەوام بێت."])]),
        ("نرخ و پارەدان", ["نرخەکان بە دیناری عێراقین و پێش داواکاری پیشان دەدرێن لەگەڵ کرێی گەیاندنی فرۆشگا. شێوازەکانی پارەدان لە کاتی تەواوکردنی داواکاری پیشان دەدرێن. چۆنیەتی پارەدان و گەڕاندنەوەی پارە و پێدانی فرۆشگاکان لێرە ڕوون دەکرێتەوە کاتێک پارەدانی ئۆنلاین چالاک دەکرێت."]),
        ("بەرهەمی زیندوو", ["ڕووەک و گوڵ سروشتین و زوو خراپ دەبن. وێنەکان بۆ ڕێنماییین و لەوانەیە بەرهەمە ڕاستەقینەکە کەمێک جیاواز بێت. ئەگەر شتێک خراپ یان هەڵە گەیشت، سەرەتا پەیوەندی بە فرۆشگاکە بکە؛ لەوانەیە یارمەتی چارەسەرکردنی بدەین."]),
        ("یاسای فرۆشگاکان", [("ul", [
            "بەرهەم و وێنە و نرخی ڕاست بنووسە و دۆخی بەردەستبوون نوێ بکەرەوە.",
            "ئەوەی قبوڵت کردووە بیگەیەنە، یان بە هۆکارێکی ڕاست هەڵیبوەشێنەرەوە.",
            "ناو و تەلەفۆن و ناونیشانی کڕیار تەنها بۆ تەواوکردنی ئەو داواکارییە بەکاربهێنە.",
            "داوا لە کڕیار مەکە داواکاری لە ئەپەکە هەڵبوەشێنێتەوە تا لە دەرەوەی ئەپەکە بیفرۆشیتە، و فرۆشتنەکە مەگوازەرەوە بۆ شوێنێکی تر.",
            "بەرهەمی یاساخ یان مەترسیدار یان هەڵخەڵەتێنەر مەفرۆشە."])]),
        ("یاسای کڕیاران", ["داواکاری ساختە مەکە، خراپ مامەڵە لەگەڵ فرۆشگا و گەیەنەران مەکە، و ئەپەکە خراپ بەکارمەهێنە."]),
        ("یاریدەدەری زیرەک", ["یاریدەدەری زیرەک زانیاری گشتی دەدات دەربارەی ڕووەک و گوڵ و دیاری و لەوانەیە هەڵە بکات. ئامۆژگاری پیشەیی نییە. بڕیاری گرنگ (وەک چارەسەری ڕووەکی نەخۆش، یان هەر شتێک پەیوەست بە کیمیا یان منداڵ یان ئاژەڵی ماڵی) لەگەڵ پسپۆڕ بپشکنە."]),
        ("ناوەڕۆک", ["فرۆشگاکان خاوەنداریەتی ئەو وێنە و نووسینانە دەپارێزن کە بارى دەکەن و مۆڵەتمان دەدەن لە ئەپەکەدا پیشانیان بدەین. ئەپەکە و دیزاین و کۆدەکەی هی ئێمەیە یان هی مۆڵەتدەرەکانمانە."]),
        ("بەرپرسیارێتی ئێمە", ["هەوڵ دەدەین ئەپەکە بەردەست و دروست بێت بەڵام ناتوانین بەڵێن بدەین هەمیشە بێ هەڵە و بێ پچڕان بێت. بەو ڕادەیەی یاسا ڕێگە دەدات، بەرپرس نین لە ڕەفتاری فرۆشگاکان یان کڕیاران، نە لە زیانی ناڕاستەوخۆ."]),
        ("یاسا و ململانێ", ["ئەم مەرجانە بەپێی یاساکانی عێراق جێبەجێ دەکرێن. ململانێکان دەچنە دادگا بەرپرسەکانی {court}."]),
        ("گۆڕانکاری و پەیوەندی", ["لەوانەیە ئەم مەرجانە نوێ بکەینەوە؛ بەردەوامبوونت لە بەکارهێنانی ئەپەکە دوای گۆڕانکاری واتە قبوڵت کردووە. پەیوەندی: {email}، {phone}."]),
    ],
}

CSS = """
body{font-family:system-ui,-apple-system,'Segoe UI',Tahoma,sans-serif;line-height:1.7;color:#1d2b2b;background:#f7f5ef;margin:0}
main{max-width:760px;margin:0 auto;padding:24px 20px 60px}
h1{color:#0b4f52;font-size:28px;margin:8px 0 4px}h2{color:#0e6f73;font-size:20px;margin:28px 0 6px}
p,li{font-size:16px}ul{padding-inline-start:22px}.meta{color:#55706f;font-size:14px}
nav{display:flex;gap:14px;flex-wrap:wrap;margin:10px 0 18px;font-size:15px}a{color:#0e6f73}
.draft{background:#fff2da;border:1px solid #b7791f;border-radius:10px;padding:8px 12px;font-size:14px;color:#6b4a10}
"""


def fill(text, lang):
    values = dict(PLACEHOLDERS[lang])
    values["app"] = APP[lang]
    return text.format(**values)


def render(kind, lang):
    meta = LANGS[lang]
    sections = (PRIVACY if kind == "privacy" else TERMS)[lang]
    title = meta["title_privacy"] if kind == "privacy" else meta["title_terms"]
    parts = []
    for heading, blocks in sections:
        parts.append("<h2>%s</h2>" % escape(heading))
        for block in blocks:
            if isinstance(block, tuple):
                parts.append("<ul>%s</ul>" % "".join("<li>%s</li>" % escape(fill(i, lang)) for i in block[1]))
            else:
                parts.append("<p>%s</p>" % escape(fill(block, lang)))
    other = " · ".join(
        '<a href="%s-%s.html">%s</a>' % (kind, code, info["name"]) for code, info in LANGS.items() if code != lang
    )
    switch = ' · '.join(
        ['<a href="privacy-%s.html">%s</a>' % (lang, LANGS[lang]["title_privacy"]), '<a href="terms-%s.html">%s</a>' % (lang, LANGS[lang]["title_terms"])]
    )
    return """<!doctype html>
<html lang="%s" dir="%s"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>%s – %s</title><style>%s</style></head><body><main>
<nav>%s</nav>
<h1>%s</h1><p class="meta">%s: %s · %s: %s</p>
%s
</main></body></html>
""" % (lang, meta["dir"], escape(title), escape(APP[lang]), CSS, switch, escape(title), meta["updated"], UPDATED, meta["other"], other, "\n".join(parts))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for kind in ("privacy", "terms"):
        for lang in LANGS:
            (OUT / ("%s-%s.html" % (kind, lang))).write_text(render(kind, lang), encoding="utf-8")
    index = "<!doctype html><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>%s</title><style>%s</style><main><h1>%s</h1>%s</main>" % (
        APP["en"], CSS, APP["en"],
        "".join(
            "<h2>%s</h2><p><a href='privacy-%s.html'>%s</a> · <a href='terms-%s.html'>%s</a></p>" % (info["name"], code, info["title_privacy"], code, info["title_terms"])
            for code, info in LANGS.items()
        ),
    )
    (OUT / "index.html").write_text(index, encoding="utf-8")
    print("wrote", len(list(OUT.glob("*.html"))), "pages to", OUT)


if __name__ == "__main__":
    main()
