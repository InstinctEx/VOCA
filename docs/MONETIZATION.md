# VOCA: paid distribution and purchase keys

## Recommended offer

Sell a one-time paid download of a supported major version, with its bug-fix updates, a convenient signed installer, and a clearly defined support period. €49 is a proposed starting price from the existing site, not a validated price or active offer. Decide whether future major upgrades are paid separately before promising “all updates forever.” Keep the license to the purchased code perpetual; keep provider API fees separate. Do not bundle unlimited third-party AI usage into a one-time fee without a sustainable cost model.

VOCA’s distinctive promise is a patient, recoverable writing workflow: personal style, destination awareness, original-word fallback, and a compact native interface. Sell that experience and maintenance, not exclusivity over inherited open-source code.

## What GPL permits and requires

GNU explicitly permits charging for GPL software. Recipients retain the rights to inspect, modify, and redistribute it. Distribute corresponding source, VOCA changes, build scripts, the GPL, and dependency notices through a compliant source-delivery arrangement. A practical direct-download approach is to place the matching source archive beside each binary release and link it from the purchase/download page. An upstream-only source link is insufficient for the modified VOCA binary.

Keeping development on GitHub private does not by itself violate the GPL. It does not remove source obligations once you deliver binaries. A private repository link that customers cannot access is not source delivery.

Sources: [GNU selling free software](https://www.gnu.org/philosophy/selling.en.html), [GPL FAQ](https://www.gnu.org/licenses/gpl-faq.en.html), [GPLv3](https://www.gnu.org/licenses/gpl-3.0.html).

## How a purchase key should work

Use a purchase key as proof of eligibility for your commercial services—supported official downloads, support, or a separately priced update service. Do not present it as a legal prohibition on exercising GPL redistribution rights. GPL recipients can modify client code; no local check makes that fact disappear.

A concrete integration option is Lemon Squeezy: it offers a merchant-of-record checkout and license key APIs. The owner must create/verify the seller account, accept its agreement, select an eligible product, and configure prices, tax, refunds, support, and payout details. Those steps cannot be invented by an implementation agent.

Implementation sequence after account setup:

1. Configure the actual store/product/variant IDs on a server you control, never trust IDs supplied only by the client.
2. Receive and authenticate purchase/refund webhooks; make handling idempotent and retain minimal purchase metadata.
3. Validate a submitted key against the licensing service and confirm its store, product, variant, status, and instance. Enforce rate limits and redact all key values in logs.
4. Return a short-lived signed receipt for paid services. Keep the private signing key server-side; ship only a public verifier with the app. Use Keychain for the purchase key. Handle offline/grace states, refunds, and device resets explicitly.
5. Keep core dictation and the user's words recoverable when the licensing service is down. Clearly separate the GPL code license from commercial service terms.
6. Test valid, wrong-product, revoked, expired, duplicated, offline, and refund cases against the real provider. Then turn on checkout.

Do not embed a Lemon Squeezy admin API key in a Swift binary or the static website. Static `config.js` may contain a public checkout URL, never a payment secret. No payment/license API was configured or called in this work.

Sources: [license generation](https://docs.lemonsqueezy.com/help/licensing/generating-license-keys), [API documentation](https://docs.lemonsqueezy.com/api), [merchant-of-record pricing](https://www.lemonsqueezy.com/pricing). Check current fees and eligibility directly before choosing a provider.

## Owner decisions needed

- Legal seller identity, support email, refund policy, supported territories and tax handling.
- Final price, support period, major-upgrade policy, checkout vendor, and domain.
- Developer ID membership/certificate and notarization credentials, kept outside Git.
- Clear rights for the pinned media-control adapter and downloaded model redistribution, or a replacement implementation with compatible terms.
- Corresponding-source delivery for every sold binary.

This is an engineering distribution plan, not legal clearance. Have final seller terms and dependency rights reviewed before accepting payment.
