# Sell the VOCA beta with Ko-fi + PayPal

Recommended September 12, 2026: **Ko-fi Shop connected to PayPal**, with a €5 digital product. No monthly subscription or custom payment server is needed. Ko-fi charges 5% on shop sales; PayPal processing and any currency-conversion fees are additional. Buy Me a Coffee uses Stripe, so it does not meet the owner's preference to avoid Stripe.

## Set up the product

1. Create your Ko-fi account and connect your own PayPal account in payment settings. Complete the provider's identity/payout requirements yourself; never place credentials in this repository.
2. Add a Shop **digital product**, named **VOCA for Mac — Beta**, priced at **€5 EUR**. This is a software sale, not a donation button.
3. Upload `VOCA-beta.zip`, `VOCA-source.zip`, `READ-ME-FIRST.md`, `SOURCE-REVISION.txt`, and `SHA256SUMS` from the same verified release folder. The September 12 smaller package has a roughly 20.4 MiB app ZIP. Do not mix a binary with source from a different release.
4. Include the description below. Add your actual seller identity, contact email, delivery/refund terms, and support/upgrade policy in the store. Ko-fi is not a merchant of record: you manage tax obligations and customer issues. Do not promise support periods or lifetime updates you have not decided to offer.
5. Use the store's product-specific share URL for checkout. Buyers receive file access through Ko-fi and their receipt; do not upload the paid ZIP into `dist/`.
6. Verify the product is available, EUR pricing is correct, all files download intact, and the receipt/terms are correct using the provider's supported test flow or an owner-authorized real transaction. Check the refund flow separately. No test purchase has been made by this project.

## Product description

> VOCA turns your voice into text in the Mac app you're using. Includes downloadable speech models, local Qwen cleanup, twelve editable writing styles, custom prompts, vocabulary tools, history, and a compact destination-aware waveform.
>
> €5 buys the convenient prebuilt beta download with all local features. The GPLv3 source is free to build at https://github.com/InstinctEx/VOCA. No activation key or subscription is required. Optional cloud AI usage is billed separately by your provider.
>
> Requires Apple Silicon and macOS 15+. Local Qwen cleanup downloads approximately 2.28 GB separately; 16 GB memory is recommended. Native Liquid Glass requires macOS 26.
>
> This beta is locally signed, **not Apple-notarized**. macOS may require manual approval under Privacy & Security and Microphone/Accessibility setup. Model accuracy, mixed-language speech and app compatibility vary. Please read the installation guide before buying.
>
> VOCA is a GPLv3 fork of FluidVoice. Your purchase does not remove your rights to study, modify or redistribute the covered software. Matching source and notices are included.

## Connect the website

`config.js` is public and must never contain payment secrets. Set:

- `checkoutUrl`: the real product URL, not a profile or donation URL.
- `deliveryMode: 'hosted-checkout'`: already configured. `downloadUrl` remains empty.
- `sourceUrl`: public archive for the exact source revision used in the delivered binary; currently pinned to the September 12 smaller beta.
- `termsUrl`: actual published product terms/refund-policy URL.
- `sellerName` and `supportEmail`: your real public seller/contact details.
- `betaDisclosureAccepted: true` once the store displays the unnotarized disclosure.
- `releaseReady: true` only once the store and delivery are verified.

Then run `node scripts/site-release-check.mjs`, `npm test`, `npm run check`, and `npm run build`. Upload only `dist/` to Cloudflare Pages. The purchase button routes directly to the hosted checkout; VOCA does not process card data or interpret a return URL as proof of payment. No activation service is needed for this edition.

## References

- [Ko-fi shop and digital delivery](https://help.ko-fi.com/hc/en-us/articles/360009712917-Ko-fi-Shop-Sell-digital-physical-products)
- [Ko-fi fees](https://help.ko-fi.com/hc/en-us/articles/360002506494-Does-Ko-fi-take-a-fee)
- [Ko-fi payment methods](https://help.ko-fi.com/hc/en-us/articles/115003980093-How-do-I-get-paid)
- [Buy Me a Coffee payment charges](https://help.buymeacoffee.com/en/articles/8105744-how-to-calculate-charges-on-your-payment)
