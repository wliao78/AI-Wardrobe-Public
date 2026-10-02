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

## Gates before submission

- Confirm a unique store name. Exact English name `AI Wardrobe` was rejected as already used. Home-screen name need not change.
- Create the App Store Connect record and upload the final archive. Repeat archive after source or localization changes.
- Inspect all localized screenshots and upload matching language sets. Current capture size: 1320 × 2868, accepted by Apple's iPhone 6.9-inch specification.
- Validate core interactions on compact and large iPhones, permission denial, photo import/cutout and data deletion. Verify any unresolved tests before marking complete.
- Exercise live provider text and image requests with explicitly authorized test credentials and costs. Fixture success does not establish live provider availability.
- Verify WeatherKit App ID service and a physical-device weather request for this public bundle.
- Supply truthful review contact details; decide whether to provide a dedicated limited reviewer API key for optional online features. Never embed a personal key in the app or repository.
- Complete privacy questionnaire consistent with the manifest and optional providers: photos/videos, other user content, provider account identifier and coarse weather location. No tracking or advertising.
- Complete age-rating, content-rights and export-compliance questionnaires using actual app behavior. AI content can vary; do not auto-answer every content category as absent without assessment.
- User must decide EU DSA trader status. Free distribution does not determine this classification. Any account agreements require explicit acceptance.
- Confirm free price, intended territories, localized names, release mode and privacy/support URLs. Submit for Apple review. Publication remains dependent on Apple's approval.

## Proposed App Review notes

AI Wardrobe is a free iPhone wardrobe organizer. No app account or login is required. The initial wardrobe includes three fictional demo combinations and ten clothing catalog items. Test Closet, Today occasion selection, refresh, favorites, local photo import and the default model selection without credentials.

Online AI is optional and uses the user's own third-party API key. Me → AI settings shows the supported providers and requires separate explicit permissions for text/wardrobe data and images; both are off by default. Keys go directly to the chosen provider and are not sent to the developer. The connection test uses a synthetic prompt, not wardrobe data. Provider charges and account/model requirements are disclosed before enabling AI. There are no purchases or subscriptions in the app.

To test visual try-on, choose OpenAI or Google Gemini with a compatible image model, save the key and sharing choices, then select a garment in Try on and tap AI image. The displayed default model before generation is explicitly labeled as a reference, not a generated result. All shipped models are fictional. Personal photos are optional. Other providers offer text recommendations only.

Me → Delete all local data removes the local wardrobe, messages, body photos, preferences and provider keys. App data is not synchronized to a developer server. Optional approximate location is used only for Apple Weather. Full privacy, provider links and usage guidance are in the app and on the public support site.

## References

- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/
- https://developer.apple.com/app-store/review/guidelines/
