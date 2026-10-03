# Release record — 1.0 (1)

This is preparation material, not a statement that the app is submitted or approved.

## Completed checks

- Seven complete interface and legal localizations and localized purpose strings.
- Separate bundle identity, portrait-only iPhone target and no private-edition resource paths.
- Seven fictional regional model pairs and three demo outfits.
- Simulator build and device archive successful on 2026-10-02.
- Fixture tests: six text-provider adapters, two image adapters, explicit consent gates, HTTPS endpoint validation, synthetic connection-test privacy and sanitized HTTP errors.
- Private source repository and public support-only website created independently.
- Seven localized store descriptions fit field character limits.
- English, Japanese, French, Spanish and Traditional Chinese version descriptions are saved in App Store Connect; the latter four were rechecked after a page reload against their source text. Each of these five locales has four independent screenshots, ordered Today, Closet, Try on, Me. All five sets and their order were rechecked after reload. All seven local Me screenshots were recaptured after removing both its large app-name heading and page title; the five existing store sets have been replaced with the new Me screenshot.

## Gates before submission

- App Store Connect record exists: `6818665093`, English name `AI My Wardrobe`, bundle `com.tinyworm.AIWardrobe.Public`. English subtitle, Lifestyle category, description, URLs and review information are saved. Release 1.0 (1) was uploaded successfully using Xcode; Apple processing and build selection remain to be confirmed in the store UI. No review submission or release has occurred.
- Simplified Chinese name attempts (`AI衣橱`, `AI我的衣橱`, `AI我的衣橱·穿搭助手`) returned later name-conflict errors despite transient Saved feedback. Reloaded language menus still exclude Simplified Chinese; do not claim these names persisted. The user approved the latest longer Chinese candidate. Traditional Chinese, Japanese, French and Spanish appear in the saved language menu; German has also returned a name-conflict error. Reconcile actual server state before submission.
- Current archive `/tmp/AIWardrobe-Public-Release-20261002-v2.xcarchive` contains the latest profile-heading removal, public bundle, portrait-only iPhone target, iOS 18 minimum, WeatherKit entitlement and non-exempt encryption set to false. Xcode export/upload succeeded (`/tmp/aiwardrobe-upload-v2.log`). Repeat archive and increment build number if shipping source changes again.
- Inspect all localized screenshots and upload matching language sets. Current capture size: 1320 × 2868, accepted by Apple's iPhone 6.9-inch specification.
- Validate core interactions on compact and large iPhones, permission denial, photo import/cutout and data deletion. Verify any unresolved tests before marking complete.
- Live provider text and image requests remain unverified. The user explicitly declined supplying test credentials at this stage; do not use private-edition credentials or claim fixture results establish live availability.
- WeatherKit capability and App Service are both visibly enabled for the exact public App ID in Apple Developer. A physical-device request remains unverified.
- Supply truthful review contact details; decide whether to provide a dedicated limited reviewer API key for optional online features. Never embed a personal key in the app or repository.
- Privacy questionnaire published after the user's explicit accuracy confirmation: photos/videos, other user content and provider account identifier, linked to the user, no tracking or advertising. Approximate location is disclosed in the policy and used only with Apple Weather; it is not retained by the developer or transmitted to AI providers. Apple-framework collection is not declared as developer collection.
- Age rating is saved with an 18+ override, explicitly approved by the user for this first release. Apple displays 18+ in 173 territories, A18 in Brazil, 19+ in Korea and corresponding older-system ratings. The ordinary clothing-organizer content/features were assessed against Apple's definitions; no public UGC feed, person-to-person chat, browser, advertising, medical guidance, gambling or intended mature imagery is built in. This is not a guarantee of third-party AI output safety. User explicitly confirmed content rights; the third-party-content rights declaration is saved and rechecked after reload. Export compliance remains to be checked with Apple's processed build.
- User explicitly confirmed Non-trader for the entire developer account. The account-wide declaration was submitted; Apple shows Digital Services Act compliance Active across 27 territories and identifies this app as non-trader. No Paid Apps Agreement was accepted.
- All 175 countries/regions are selected and visibly show `Available on App Release`. Free pricing was saved for all 175 territories. Apple Silicon Mac and Vision Pro availability are disabled: this first release is scoped to iPhone. This is a release configuration, not present store discoverability; territory-specific compliance can still affect availability. Confirm localized names, release mode and privacy/support URLs. Submit for Apple review. Publication remains dependent on Apple's approval.

## Proposed App Review notes

AI Wardrobe is a free iPhone wardrobe organizer. No app account or login is required. The initial wardrobe includes three fictional demo combinations and ten clothing catalog items. Test Closet, Today occasion selection, refresh, favorites, local photo import and the default model selection without credentials.

Online AI is optional and uses the user's own third-party API key. Me → AI settings shows the supported providers and requires separate explicit permissions for text/wardrobe data and images; both are off by default. Keys go directly to the chosen provider and are not sent to the developer. The connection test uses a synthetic prompt, not wardrobe data. Provider charges and account/model requirements are disclosed before enabling AI. There are no purchases or subscriptions in the app.

To test visual try-on, choose OpenAI or Google Gemini with a compatible image model, save the key and sharing choices, then select a garment in Try on and tap AI image. The displayed default model before generation is explicitly labeled as a reference, not a generated result. All shipped models are fictional. Personal photos are optional. Other providers offer text recommendations only.

Me → Delete all local data removes the local wardrobe, messages, body photos, preferences and provider keys. App data is not synchronized to a developer server. Optional approximate location is used only for Apple Weather. Full privacy, provider links and usage guidance are in the app and on the public support site.

## In-progress simulator QA — voice additions

- Eight hosted tests passed for speech lifecycle, authorization errors, late callbacks, stop during authorization, locale mapping, demo persistence/removal and corrupt-file preservation.
- Both dedicated iPhone 18 Pro Max and iPhone 17e simulators passed ten tests each: eight hosted tests plus general UI coverage for seven-language launch, draft entry, immediate send, localized labels, navigation, clothing editing, full-size image display, favorites and camera entry/dismissal. Both result bundles report zero runtime warnings. Real speech tests are excluded from those ten-test passing results.
- A real authorization callback crash was reproduced and traced to Swift 6 MainActor inheritance in the legacy Apple callback. The callback now originates in a nonisolated helper.
- iOS 27 simulator logs show Apple's local recognizer failing to load its model; this runtime limitation remains. An official iOS 26 runtime was installed, and a dedicated iPhone 16 Pro Max simulator passed actual microphone start/stop and page-navigation tests in all seven languages (three cycles each): `/tmp/AIWardrobe-Public-iOS26-MultilingualVoice-10.xcresult`. Real Apple Speech recognition also passed seven synthetic audio-file phrases with keyword verification: `/tmp/AIWardrobe-Public-iOS26-Transcription-9.xcresult`. These are not mocked recognizer results, but do not establish live human microphone transcription end-to-end.
- Ten hosted tests now pass, including successful data-erasure persistence without demo reseeding and preservation of existing data if credential deletion fails: `/tmp/AIWardrobe-Public-Data-Unit-11.xcresult`. Erasure tests inject a credential-reset dependency and do not delete real provider keys.
- A demo JPEG was manually imported through Photos and processed. The six-provider selector and Claude's text-only notice were checked; no paid request was sent. Physical camera capture, HEIC import, permission denial and data deletion still need their remaining coverage. Older failed UI-test runs include selector/permission-handling failures; do not present them as passing coverage.
- Twenty-eight full-resolution screenshots were recaptured after making the office catalog shoes match the brown penny loafers in the outfit. User enabled Chrome extension file-URL access; four English screenshots were uploaded and are visibly present in the 6.9-inch slot, automatically used for 6.5-inch. Other localized uploads and screenshot order remain to be completed.
- Seven-language support pages now include optional voice usage and privacy disclosures. Public support commit: `c378c59`.
- Eleven hosted tests passed with zero runtime warnings after adding actual HEIC encoding/decoding, orientation, corrupt-image rejection and pixel-limit tests: `/tmp/AIWardrobe-Public-Photo-Unit-12.xcresult`. Fixed renderer scale so the catalog is actually 768×768 pixels and photo compression does not multiply dimensions by device display scale. Photos-picker HEIC import remains a separate UI test gate.
- Two additional real UI tests passed: denied microphone permission still allows typed conversation, and deleting the isolated test wardrobe leaves it empty across tab navigation: `/tmp/AIWardrobe-Public-Permissions-Erasure-14.xcresult`. The first erasure attempt failed on a nested SwiftUI test selector, corrected to firstMatch. DEBUG UI-test erasure uses a no-op credential reset and does not touch real provider keys.
- Latest source, including removal of the profile's large app-name heading, passed eleven hosted checks and three general UI tests covering seven-language draft/send/tab navigation, clothing edit/zoom/favorite/camera dismissal and isolated erasure: `/tmp/AIWardrobe-Public-Latest-General-15.xcresult`.
- After also removing the small profile navigation title, two navigation/erasure UI regressions passed with zero runtime warnings: `/tmp/AIWardrobe-Public-Profile-Navigation-17.xcresult`.
- Actual Photos-picker HEIC import passed manually on the dedicated compact simulator, using an HEIC converted from the public demo navy polo, not personal photos. The processed garment was saved, searched, reopened and enlarged with complete sleeves/hem. Proof: `/tmp/AIWardrobe-heic-import-enlarge.png`. Physical-camera capture and public-bundle physical-weather requests remain unverified.

## References

- https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store
- https://developer.apple.com/app-store/app-privacy-details/
- https://developers.openai.com/api/docs/models/gpt-image-2.5-flare
- https://developers.openai.com/api/docs/models/gpt-4.1-mini
- https://api-docs.deepseek.com/api/list-models/
- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/
- https://developer.apple.com/app-store/review/guidelines/
