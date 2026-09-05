# ResaleProfit

An iOS app for flipping/resale shoppers: photograph an item, enter the
seller's asking price, and get back the real average eBay listing price and
estimated profit.

## How it works

1. Take a photo of an item (or pick one from your library).
2. Enter the price the seller is asking.
3. The app sends the photo to Claude (vision) to identify the item (brand,
   model, category) and assess its condition.
4. It searches eBay's Browse API for that item and averages the price
   across current active listings.
5. It shows the average listing price and the estimated profit (average
   price minus asking price).

If no eBay developer keys are configured (or the lookup fails/finds
nothing), it falls back to an AI-estimated price range from Claude's
general market knowledge, and the result card says so.

Note: this uses eBay's public Browse API, which covers *active* listings.
eBay's sold/completed-listings data (Marketplace Insights API) requires a
separate restricted partner application that isn't generally available, so
"average listing price" here means current asking prices on eBay, not
confirmed sold prices.

## Project structure

```
ResaleProfit/
  project.yml                        # XcodeGen spec - generates the .xcodeproj
  Resources/
    Info.plist
  Sources/ResaleProfit/
    App/ResaleProfitApp.swift        # App entry point
    Models/ItemAppraisal.swift       # Appraisal, price source, profit calculation
    Services/AppraisalService.swift  # Calls the Claude API (item ID + condition)
    Services/EbayPricingService.swift# eBay OAuth + Browse API average price lookup
    Services/KeychainService.swift   # Stores API keys in the Keychain
    Views/HomeView.swift             # Camera capture + asking price + results
    Views/ResultCardView.swift       # Profit result card
    Views/SettingsView.swift         # API key entry (Anthropic + eBay)
    Views/ImagePicker.swift          # UIImagePickerController wrapper
```

## Building

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to
generate the `.xcodeproj` from `project.yml`, so no binary Xcode project
file is checked into git.

```bash
brew install xcodegen   # one-time
cd ResaleProfit
xcodegen generate
open ResaleProfit.xcodeproj
```

Then build and run on a simulator or device (⌘R) in Xcode. The camera only
works on a physical device; use "Photo Library" in the simulator.

## Setup

On first launch, tap the gear icon and enter:

- **Anthropic API key** (from https://console.anthropic.com/) - used to
  identify the item and its condition from your photo.
- **eBay App ID / Cert ID** (optional but recommended) - powers the real
  average listing price.
  1. Sign up at https://developer.ebay.com/ and create an application.
  2. Generate a **production keyset**; copy the *App ID (Client ID)* and
     *Cert ID (Client Secret)*.
  3. No further eBay approval is needed - the Browse API's
     `client_credentials` OAuth scope (`https://api.ebay.com/oauth/api_scope`)
     is available to any registered app for public item search.

Both sets of keys are stored in the iOS Keychain and used only to call
`api.anthropic.com` and `api.ebay.com` directly from the device.

## Notes / possible improvements

- No backend is required - the app talks to the Anthropic and eBay APIs
  directly, which means both API keys live on-device. For a shipped App
  Store app, route these calls through your own backend instead so the
  keys aren't embedded in the client.
- The eBay average is computed from up to 25 current fixed-price listings
  matching the identified item name; it doesn't yet filter by the exact
  condition Claude detected (e.g. "used - good") since eBay's condition
  filters don't map cleanly onto free-text descriptions.
- For confirmed *sold* comps instead of active listings, apply for eBay's
  Marketplace Insights API (restricted access) and swap it into
  `EbayPricingService`.
