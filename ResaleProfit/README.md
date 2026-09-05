# ResaleProfit

An iOS app for flipping/resale shoppers: photograph an item, enter the
seller's asking price, and get back an estimated average resale price and
profit.

## How it works

1. Take a photo of an item (or pick one from your library).
2. Enter the price the seller is asking.
3. The app sends the photo to Claude (vision) to identify the item and
   estimate the average price it resells for on secondhand marketplaces,
   given its apparent condition.
4. It shows the average listing price and the estimated profit (average
   price minus asking price).

This is a market *estimate* from the model's general knowledge, not a live
scrape of eBay/Poshmark/etc. sold listings.

## Project structure

```
ResaleProfit/
  project.yml                        # XcodeGen spec - generates the .xcodeproj
  Resources/
    Info.plist
  Sources/ResaleProfit/
    App/ResaleProfitApp.swift        # App entry point
    Models/ItemAppraisal.swift       # Appraisal + profit calculation
    Services/AppraisalService.swift  # Calls the Claude API
    Services/KeychainService.swift   # Stores the API key in the Keychain
    Views/HomeView.swift             # Camera capture + asking price + results
    Views/ResultCardView.swift       # Profit result card
    Views/SettingsView.swift         # API key entry
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

On first launch, tap the gear icon and paste an Anthropic API key
(from https://console.anthropic.com/). It's stored in the iOS Keychain and
used only to call `api.anthropic.com` directly from the device.

## Notes / possible improvements

- The average price is a model estimate. For real sold-listing data, swap
  `AppraisalService` to also call an eBay/marketplace API and blend that
  with the vision identification.
- No backend is required - the app talks to the Anthropic API directly,
  which means the API key lives on-device. For a shipped App Store app,
  route this through your own backend instead so the key isn't embedded
  in the client.
