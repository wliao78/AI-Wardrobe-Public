# AI My Wardrobe — public edition

Independent, multilingual iPhone wardrobe app. Free local features; optional AI uses the user's own provider account and API key. This repository is private. The distributed app and its support website are public.

## Identity

- Bundle ID: `com.tinyworm.AIWardrobe.Public`
- iPhone, iOS 18 or later, portrait only.
- English, Simplified Chinese, Traditional Chinese, Japanese, French, German and Spanish.
- Localized home-screen names, including AI My Wardrobe and AI衣橱.
- No personal-edition history, photos, garment catalog, credentials or saved conversations.

## Features

Local photo-based wardrobe, complete-silhouette catalog processing, three demo combinations, occasion-based combinations, favorites, optional Apple Weather, optional personal reference photos, and seven regional fictional male/female reference pairs. Defaults follow app language and region and can be changed manually; they do not infer the user's identity or nationality.

OpenAI-compatible adapters cover OpenAI, Gemini, DeepSeek, Qwen and custom HTTPS endpoints. Anthropic uses native Messages. Image generation is supported for OpenAI and Gemini only. Model IDs and account capabilities can change. Users must explicitly consent before clothing/conversation or photo transmission. API keys use device-only Keychain storage; redirects are refused. No developer content backend, ads or analytics.

## Build and verify

Open `AIWardrobe.xcodeproj`, select the AIWardrobe scheme and an iPhone destination. Configure your own signing team when forking. Enable WeatherKit for the exact public bundle ID and its App ID service in Apple Developer; provisioning alone does not verify production WeatherKit access.

Run `node Tests/verify-release.mjs` with Node 22 or later. Compile and run `Tests/AIClientTests.swift` together with `AIWardrobe/Services/AIClient.swift` using Swift 6. Provider tests use controlled responses, not live paid requests. `Tests/capture-screenshots.sh <simulator-id>` captures the four actual screens in seven languages after the simulator build is installed. Use a dedicated simulator, not one shared with another task.

The shared Xcode scheme includes hosted lifecycle/persistence tests and UI tests. Run `xcodebuild test` against a dedicated simulator; `-collect-test-diagnostics never` avoids lengthy sysdiagnose collection on a failed test. Real microphone tests are separate from mocked lifecycle tests. Do not claim speech recognition is verified merely because the UI and lifecycle tests pass. Current speech verification limitations are recorded in `AppStore/RELEASE.md`.

## Release materials

`AppStore/Metadata` contains localized descriptions, subtitles, keywords, promotional text and support/privacy URLs. `AppStore/Screenshots` contains unaltered localized simulator screenshots. Descriptions disclose paid provider usage, permissions, local-only storage and the limitations of visual try-on. Review notes and outstanding release gates are in `AppStore/RELEASE.md`.

Public support and seven-language guides: https://wliao78.github.io/AI-Wardrobe-Support/

## Data and deletion

Wardrobe JSON is stored in Application Support, excluded from backup, and protected with iOS file protection. Delete all local data removes the local wardrobe and saved provider keys. Uninstalling can leave Keychain entries; delete keys in the app first. Data already sent to a provider is governed by that provider and cannot be retracted by local deletion. Keep separate copies of important original photos.
