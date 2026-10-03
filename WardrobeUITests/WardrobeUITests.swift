import XCTest

final class WardrobeUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testProfilePhotoEditorAndProviderWithoutAPIKey() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.tabBars.buttons.element(boundBy: 3).tap()
        let front = app.buttons["profile.photo.front"]
        for _ in 0..<5 where !front.isHittable { app.swipeUp() }
        XCTAssertTrue(front.isHittable); front.tap()
        XCTAssertTrue(app.buttons["photo.library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["photo.camera"].exists)
        app.buttons["bodyPhoto.close"].tap()
        let settings = app.descendants(matching: .any).matching(identifier: "profile.aiSettings").firstMatch
        for _ in 0..<5 where !settings.isHittable { app.swipeUp() }
        XCTAssertTrue(settings.isHittable); settings.tap()
        let provider = app.descendants(matching: .any).matching(identifier: "ai.provider").firstMatch
        XCTAssertTrue(provider.waitForExistence(timeout: 5)); provider.tap()
        app.buttons["DeepSeek"].firstMatch.tap()
        XCTAssertEqual(app.textFields["ai.model"].value as? String, "deepseek-flash")
        XCTAssertFalse(app.textFields["ai.imageModel"].exists)
        XCTAssertFalse(app.buttons["ai.testConnection"].isEnabled, "Never call a live provider without a user-supplied key")
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "deepseek-no-key-settings"; shot.lifetime = .keepAlways; add(shot)
        // No settings or key are saved: provider selection is an unsaved draft.
        app.terminate()
    }

    @MainActor func testPrivateLayoutPreviewAndTopFavorites() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let favorites = app.buttons["today.savedLooks"]
        let preview = app.buttons["today.preview"]
        XCTAssertTrue(favorites.waitForExistence(timeout: 10))
        XCTAssertEqual(favorites.value as? String, "0")
        // XCTest reports the visible photograph, not its 610-point stage;
        // on compact phones the scroll viewport clips that accessibility frame.
        XCTAssertGreaterThan(preview.frame.width, app.frame.width * 0.85)
        XCTAssertGreaterThan(preview.frame.height, app.frame.height * 0.60)
        XCTAssertLessThan(favorites.frame.maxY, preview.frame.minY)
        let refreshFrame = app.buttons["look.newLook"].frame
        let initialShot = XCTAttachment(screenshot: app.screenshot())
        initialShot.name = "private-layout-home-initial"; initialShot.lifetime = .keepAlways; add(initialShot)
        app.buttons["look.saveLook"].tap()
        XCTAssertEqual(favorites.value as? String, "1")
        favorites.tap()
        let close = app.buttons["savedLooks.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        let savedShot = XCTAttachment(screenshot: app.screenshot())
        savedShot.name = "private-layout-top-favorites"; savedShot.lifetime = .keepAlways; add(savedShot)
        close.tap()
        let input = app.textFields["chat.input"].exists ? app.textFields["chat.input"] : app.textViews["chat.input"]
        input.tap(); input.typeText("A casual outfit today")
        XCTAssertTrue(app.buttons["chat.dismissKeyboard"].exists)
        XCTAssertEqual(app.buttons["look.newLook"].frame.minY, refreshFrame.minY, accuracy: 2, "Keyboard must not move the preview's top controls")
        sendDraft(in: app)
        let homeShot = XCTAttachment(screenshot: app.screenshot())
        homeShot.name = "private-layout-home-conversation"; homeShot.lifetime = .keepAlways; add(homeShot)
        app.tabBars.buttons.element(boundBy: 2).tap()
        let tryOn = app.buttons["tryon.photo"]
        XCTAssertTrue(tryOn.waitForExistence(timeout: 5))
        XCTAssertEqual(tryOn.frame.height / tryOn.frame.width, 1.5, accuracy: 0.03)
        XCTAssertFalse(app.buttons["tryon.aiImage"].exists, "Private layout shows garment actions only after selecting a photo")
        app.tabBars.buttons.element(boundBy: 3).tap()
        XCTAssertTrue(app.textFields["profile.height"].isHittable)
        XCTAssertTrue(app.textFields["profile.weight"].isHittable)
        app.terminate()
    }

    @MainActor func testCompactChatWithKeyboard() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let input = app.textFields["chat.input"].exists ? app.textFields["chat.input"] : app.textViews["chat.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap(); input.typeText("A casual outfit today")
        XCTAssertTrue(app.buttons["chat.send"].isHittable)
        sendDraft(in: app)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "compact-chat-after-send"; shot.lifetime = .keepAlways; add(shot)
        XCTAssertTrue(app.staticTexts["A casual outfit today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["chat.collapse"].exists)
        app.terminate()
    }

    @MainActor func testConversationCollapsesByHeaderAndArrowWithoutLosingHistory() {
        for (language, locale) in [("en", "en_US"), ("zh-Hans", "zh_CN")] {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
            app.launch()
            let input = app.textFields["chat.input"].exists ? app.textFields["chat.input"] : app.textViews["chat.input"]
            XCTAssertTrue(input.waitForExistence(timeout: 10))
            let compactHeight = input.frame.height
            input.tap()
            XCTAssertTrue(app.buttons["chat.dismissKeyboard"].waitForExistence(timeout: 8), "Input must actually receive focus before typing")
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
            input.typeText("Keep this wardrobe conversation")
            sendDraft(in: app)
            let collapse = app.buttons["chat.collapse"]
            XCTAssertTrue(collapse.waitForExistence(timeout: 5))
            XCTAssertGreaterThan(collapse.frame.width, app.frame.width * 0.80)
            XCTAssertGreaterThanOrEqual(collapse.frame.height, 44)
            // A normal finger tap anywhere on the title row must work, not
            // just a precision tap at the center of a small chevron glyph.
            collapse.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
            XCTAssertFalse(app.scrollViews["chat.conversation"].exists)
            XCTAssertFalse(collapse.exists)
            XCTAssertEqual(input.frame.height, compactHeight, accuracy: 2)
            XCTAssertTrue(input.isHittable)
            let collapsed = XCTAttachment(screenshot: app.screenshot())
            collapsed.name = "\(language)-conversation-collapsed"; collapsed.lifetime = .keepAlways; add(collapsed)
            input.tap()
            XCTAssertTrue(collapse.waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["Keep this wardrobe conversation"].exists, "Collapsing must not erase history")
            collapse.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            XCTAssertFalse(collapse.exists)
            XCTAssertFalse(app.keyboards.firstMatch.exists)
            app.terminate()
        }
    }

    @MainActor func testDarkLargeTextNavigationAndFavorites() {
        // The dedicated small-screen runner sets dark appearance and XXXL
        // Dynamic Type before launching; no production data or credentials.
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        let saved = app.buttons["today.savedLooks"]
        XCTAssertTrue(saved.waitForExistence(timeout: 10)); XCTAssertTrue(saved.isHittable)
        saved.tap()
        XCTAssertTrue(app.buttons["savedLooks.close"].waitForExistence(timeout: 5))
        app.buttons["savedLooks.close"].tap()
        XCTAssertTrue(app.buttons["look.newLook"].isHittable)
        app.buttons["look.newLook"].tap()
        for tab in [1, 2, 3, 0] {
            app.tabBars.buttons.element(boundBy: tab).tap()
            XCTAssertTrue(app.tabBars.buttons.element(boundBy: tab).isSelected)
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "small-dark-xxxl-de-tab-\(tab)"; shot.lifetime = .keepAlways; add(shot)
        }
        let input = app.textFields["chat.input"].exists ? app.textFields["chat.input"] : app.textViews["chat.input"]
        XCTAssertTrue(input.isHittable)
        input.tap(); input.typeText("A casual outfit on a small screen")
        sendDraft(in: app)
        XCTAssertTrue(app.staticTexts["chat.latestMessage"].isHittable)
        app.buttons["chat.collapse"].tap()
        XCTAssertTrue(app.buttons["chat.microphone"].isHittable)
        app.terminate()
    }

    @MainActor func testPhotoImportTryOnRowsAndAddToCloset() {
        // The dedicated QA simulator's latest photos are public demo HEICs;
        // older entries are Apple fixtures, not the owner's photographs.
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.tabBars.buttons.element(boundBy: 2).tap()
        app.buttons["photo.library"].tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 30))
        photo.tap()
        let thumbnail = app.buttons["tryon.garmentPhoto"]
        XCTAssertTrue(thumbnail.waitForExistence(timeout: 45))
        thumbnail.tap()
        XCTAssertTrue(app.buttons["photo.close"].waitForExistence(timeout: 5))
        app.buttons["photo.close"].tap()
        let addButton = app.buttons["tryon.add"]
        for _ in 0..<3 where !addButton.isHittable { app.swipeUp() }
        XCTAssertTrue(addButton.isEnabled)
        XCTAssertEqual(addButton.frame.midY, app.buttons["tryon.aiImage"].frame.midY, accuracy: 3)
        XCTAssertEqual(app.textFields["tryon.name"].frame.midY, app.textFields["tryon.color"].frame.midY, accuracy: 3)
        let name = app.textFields["tryon.name"]
        name.tap()
        if let value = name.value as? String { name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)) }
        name.typeText("Imported QA polo")
        addButton.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.firstMatch.buttons.firstMatch.tap()
        app.tabBars.buttons.element(boundBy: 1).tap()
        let imported = app.staticTexts["Imported QA polo"]
        for _ in 0..<5 where !imported.isHittable { app.swipeUp() }
        XCTAssertTrue(imported.isHittable)
        imported.tap()
        XCTAssertTrue(app.buttons["garment.photo"].waitForExistence(timeout: 5))
        app.buttons["garment.photo"].tap()
        XCTAssertTrue(app.buttons["photo.close"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "imported-processed-garment-full-size"; shot.lifetime = .keepAlways; add(shot)
        app.terminate()
    }

    @MainActor func testOfflineModelAcrossScenesAndNewCombinations() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        for scene in ["Office", "Weekend", "Outdoors"] {
            app.buttons[scene].tap()
            var combinations = Set<String>()
            for variation in 0..<3 {
                let model = app.descendants(matching: .any).matching(identifier: "today.localPreview").firstMatch
                XCTAssertTrue(model.waitForExistence(timeout: 10))
                let ready = NSPredicate(format: "value CONTAINS %@", "ready")
                expectation(for: ready, evaluatedWith: model)
                waitForExpectations(timeout: 30)
                let ids = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.item.")).allElementsBoundByIndex.map(\.identifier).sorted().joined(separator: ",")
                XCTAssertTrue(combinations.insert(ids).inserted, "Refresh must produce a new \(scene) combination")
                let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "\(scene)-\(variation)-local-model"; shot.lifetime = .keepAlways; add(shot)
                app.buttons["look.newLook"].tap()
            }
        }
        app.terminate()
    }

    @MainActor func testRecommendationExcludesDeselectedClothing() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["look.newLook"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.buttons["closet.selection"].tap()
        app.buttons["closet.item.white-oxford"].tap()
        app.buttons["closet.selection"].tap()
        app.tabBars.buttons.element(boundBy: 0).tap()
        for _ in 0..<3 {
            let selected = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.item.")).allElementsBoundByIndex
            XCTAssertGreaterThanOrEqual(selected.count, 3)
            XCTAssertFalse(selected.contains { $0.label == "White Oxford shirt" })
            app.buttons["look.newLook"].tap()
        }
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.buttons["closet.restoreAll"].tap()
        XCTAssertFalse(app.buttons["closet.restoreAll"].exists, "Private layout removes Restore All once the whole closet participates")
        app.terminate()
    }

    @MainActor func testPrivateBaselineMeasurementsAndCollapsibleConversation() {
        for (language, locale, decimal) in [("en", "en_CA", "70.5"), ("fr", "fr_FR", "70,5")] {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-AppleMetricUnits", "YES"]
            app.launch()
            let thumbnail = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.item.")).firstMatch
            XCTAssertTrue(thumbnail.waitForExistence(timeout: 10))
            XCTAssertLessThan(thumbnail.frame.midX, app.frame.midX)
            thumbnail.tap()
            XCTAssertTrue(app.buttons["garment.photo"].waitForExistence(timeout: 5))
            app.buttons["garment.cancel"].tap()
            let input = app.textFields["chat.input"].exists ? app.textFields["chat.input"] : app.textViews["chat.input"]
            input.tap(); input.typeText("Latest wardrobe conversation")
            sendDraft(in: app)
            XCTAssertTrue(app.buttons["chat.collapse"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["chat.latestMessage"].isHittable)
            app.buttons["chat.collapse"].tap()
            XCTAssertFalse(app.staticTexts["Latest wardrobe conversation"].exists)
            app.tabBars.buttons.element(boundBy: 3).tap()
            let height = app.textFields["profile.height"]
            XCTAssertTrue(height.waitForExistence(timeout: 5)); height.tap(); height.typeText("175")
            let weight = app.textFields["profile.weight"]
            weight.tap(); weight.typeText(decimal)
            app.buttons["profile.saveDetails"].tap()
            app.tabBars.buttons.element(boundBy: 1).tap()
            app.tabBars.buttons.element(boundBy: 3).tap()
            XCTAssertEqual(height.value as? String, "175")
            XCTAssertEqual(weight.value as? String, decimal)
            app.terminate()
        }
    }

    @MainActor func testRegionalHeightAndWeightInputPersistence() {
        let cases: [(String, String, String, String?, String, String?)] = [
            ("en", "en_US", "5", "9", "155.4", nil),
            ("en", "en_GB", "5", "9", "11", "1.4"),
            ("fr", "fr_FR", "175", nil, "70,5", nil),
            ("zh-Hans", "en_US", "5", "9", "155.4", nil)
        ]
        for (language, locale, height, inches, weight, pounds) in cases {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-AppleMetricUnits", locale == "en_US" ? "NO" : "YES"]
            app.launch(); app.tabBars.buttons.element(boundBy: 3).tap()
            let h = app.textFields["profile.height"], w = app.textFields["profile.weight"]
            XCTAssertTrue(h.waitForExistence(timeout: 5)); h.tap(); h.typeText(height)
            XCTAssertEqual(h.value as? String, height, "Verify entered text before interpreting or converting it")
            XCTAssertEqual(app.textFields["profile.heightInches"].exists, inches != nil)
            if let inches { let field = app.textFields["profile.heightInches"]; field.tap(); field.typeText(inches) }
            w.tap(); w.typeText(weight)
            XCTAssertEqual(w.value as? String, weight, "Verify the decimal keyboard delivered the intended number")
            XCTAssertEqual(app.textFields["profile.weightPounds"].exists, pounds != nil)
            if let pounds { let field = app.textFields["profile.weightPounds"]; field.tap(); field.typeText(pounds) }
            app.buttons["profile.saveDetails"].tap()
            XCTAssertFalse(app.alerts.firstMatch.exists)
            app.tabBars.buttons.element(boundBy: 1).tap(); app.tabBars.buttons.element(boundBy: 3).tap()
            XCTAssertEqual(h.value as? String, height); XCTAssertEqual(w.value as? String, weight)
            if let inches { XCTAssertEqual(app.textFields["profile.heightInches"].value as? String, inches) }
            if let pounds { XCTAssertEqual(app.textFields["profile.weightPounds"].value as? String, pounds) }
            let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "measurements-\(language)-\(locale)"; shot.lifetime = .keepAlways; add(shot)
            app.terminate()
        }
    }

    @MainActor func testOfflineClosetEditEnlargeFavoriteAndCameraFallback() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["look.saveLook"].waitForExistence(timeout: 10))
        app.buttons["look.saveLook"].tap()
        for _ in 0..<4 { app.buttons["look.newLook"].tap() }
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.buttons["closet.edit.white-oxford"].tap()
        app.buttons["garment.photo"].tap()
        XCTAssertTrue(app.buttons["photo.close"].waitForExistence(timeout: 5))
        app.buttons["photo.close"].tap()
        let name = app.textFields["garment.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        if let value = name.value as? String { name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)) }
        name.typeText("My edited shirt")
        app.buttons["garment.save"].tap()
        XCTAssertTrue(app.staticTexts["My edited shirt"].waitForExistence(timeout: 5))
        app.tabBars.buttons.element(boundBy: 2).tap()
        app.buttons["tryon.photo"].tap()
        XCTAssertTrue(app.buttons["photo.close"].waitForExistence(timeout: 5))
        app.buttons["photo.close"].tap()
        app.buttons["photo.camera"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.alerts.firstMatch.waitForExistence(timeout: 3), springboard.alerts.firstMatch.buttons["Allow"].exists { springboard.alerts.firstMatch.buttons["Allow"].tap() }
        if app.buttons["DismissButton"].waitForExistence(timeout: 5) { app.buttons["DismissButton"].tap() }
        else if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        else {
            XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
            app.alerts.firstMatch.buttons.firstMatch.tap()
        }
        app.tabBars.buttons.element(boundBy: 3).tap()
        app.swipeUp()
        let saved = app.buttons["profile.savedLooks"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5)); saved.tap()
        XCTAssertTrue(app.buttons["Office"].exists || app.staticTexts["Office"].exists)
        app.terminate()
    }

    @MainActor func testSevenLanguagesDraftSendAndTabs() {
        let locales = [("en","en_US","Today","Closet","Try on","Me"),("zh-Hans","zh_CN","今天","衣橱","试穿","我的"),("zh-Hant","zh_TW","今天","衣櫥","試穿","我的"),("ja","ja_JP","今日","クローゼット","試着","マイページ"),("fr","fr_FR","Aujourd’hui","Garde-robe","Essayage","Profil"),("de","de_DE","Heute","Kleiderschrank","Anprobe","Profil"),("es","es_ES","Hoy","Armario","Probar","Perfil")]
        for (language, region, today, closet, tryOn, profile) in locales {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-AppleLanguages", "(\(language))", "-AppleLocale", region]
            app.launch()
            let input = app.textFields["chat.input"].exists ? app.textFields["chat.input"] : app.textViews["chat.input"]
            XCTAssertTrue(input.waitForExistence(timeout: 10), language)
            input.tap(); input.typeText("A casual outfit today")
            XCTAssertTrue(String(describing: input.value ?? "").contains("A casual outfit today"), language)
            sendDraft(in: app)
            XCTAssertTrue(app.staticTexts["A casual outfit today"].waitForExistence(timeout: 5), language)
            XCTAssertTrue(app.staticTexts["chat.latestMessage"].isHittable, language + " latest reply must be visible")
            let tabs = app.tabBars.buttons
            XCTAssertEqual(tabs.count, 4, language)
            for (index, label) in [today,closet,tryOn,profile].enumerated() { XCTAssertTrue(tabs.element(boundBy: index).label.contains(label), language + " expected " + label) }
            for index in [1,2,3,0] {
                tabs.element(boundBy: index).tap()
                XCTAssertTrue(tabs.element(boundBy: index).isSelected, "\(language) tab \(index)")
                let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "\(language)-tab-\(index)"; shot.lifetime = .keepAlways; add(shot)
            }
            XCTAssertTrue(app.buttons["chat.microphone"].exists, language)
            app.terminate()
        }
    }

    @MainActor func testRealMicrophoneStartStopAndNavigate() {
        checkRealMicrophone(language: "en", region: "en_US")
    }

    @MainActor private func sendDraft(in app: XCUIApplication) {
        let send = app.buttons["chat.send"]
        // Typing through XCTest can finish before the software keyboard's
        // locale-specific animation. Do not tap its stale, covered location.
        let aboveKeyboard = NSPredicate { _, _ in
            guard send.exists, send.isHittable else { return false }
            let keyboard = app.keyboards.firstMatch
            return !keyboard.exists || send.frame.maxY <= keyboard.frame.minY
        }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: aboveKeyboard, evaluatedWith: send)], timeout: 8), .completed)
        send.tap()
    }

    @MainActor func testIsolatedDataDeletionAndEmptyCloset() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["closet.item.white-oxford"].waitForExistence(timeout: 5))
        app.tabBars.buttons.element(boundBy: 3).tap()
        let erase = app.buttons["profile.erase"]
        for _ in 0..<6 where !erase.isHittable { app.swipeUp() }
        XCTAssertTrue(erase.isHittable)
        erase.tap()
        let confirm = app.buttons["profile.confirmErase"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertFalse(app.buttons["closet.item.white-oxford"].exists)
        app.tabBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertFalse(app.buttons["closet.item.white-oxford"].exists, "Deleted demo must not automatically reappear")
        app.terminate()
    }

    @MainActor func testDeniedMicrophoneStillAllowsTyping() {
        // The runner revokes microphone permission for this test app before execution.
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["chat.microphone"].waitForExistence(timeout: 10))
        app.buttons["chat.microphone"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 10))
        XCTAssertNotEqual(app.buttons["chat.microphone"].value as? String, "listening")
        app.alerts.firstMatch.buttons.firstMatch.tap()
        let input = app.textFields["chat.input"].exists ? app.textFields["chat.input"] : app.textViews["chat.input"]
        input.tap(); input.typeText("A casual outfit without microphone")
        app.buttons["chat.send"].tap()
        XCTAssertTrue(app.staticTexts["A casual outfit without microphone"].waitForExistence(timeout: 5))
        app.terminate()
    }

    @MainActor func testSevenLanguagesRealMicrophoneLifecycle() {
        for (language, region) in [("en","en_US"),("zh-Hans","zh_CN"),("zh-Hant","zh_TW"),("ja","ja_JP"),("fr","fr_FR"),("de","de_DE"),("es","es_ES")] {
            checkRealMicrophone(language: language, region: region)
        }
    }

    @MainActor func testRecognizerFailureReturnsToTyping() {
        // Run on the dedicated iOS 27 simulator with its recorded Apple
        // recognizer-asset initialization failure. This is failure recovery,
        // not a substitute for the separate real transcription tests.
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let mic = app.buttons["chat.microphone"]
        XCTAssertTrue(mic.waitForExistence(timeout: 10)); mic.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<2 {
            let alert = springboard.alerts.firstMatch
            if alert.waitForExistence(timeout: 3), alert.buttons["Allow"].exists { alert.buttons["Allow"].tap() }
            else if alert.exists, alert.buttons["OK"].exists { alert.buttons["OK"].tap() }
        }
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 30), "Expected the recorded recognizer initialization error to be surfaced")
        XCTAssertEqual(mic.value as? String, "idle", "Recognition failure must release the microphone")
        app.alerts.firstMatch.buttons.firstMatch.tap()
        let input = app.textFields["chat.input"].exists ? app.textFields["chat.input"] : app.textViews["chat.input"]
        input.tap(); input.typeText("A casual outfit after speech failure")
        sendDraft(in: app)
        XCTAssertTrue(app.staticTexts["A casual outfit after speech failure"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["chat.latestMessage"].isHittable)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "recognizer-failure-typing-recovery"; shot.lifetime = .keepAlways; add(shot)
        app.terminate()
    }

    @MainActor private func checkRealMicrophone(language: String, region: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(\(language))", "-AppleLocale", region]
        addUIInterruptionMonitor(withDescription: "Apple speech and microphone permission") { alert in
            for title in ["Allow", "OK"] where alert.buttons[title].exists { alert.buttons[title].tap(); return true }
            return false
        }
        app.launch()
        let mic = app.buttons["chat.microphone"]
        XCTAssertTrue(mic.waitForExistence(timeout: 10))
        for cycle in 0..<3 {
            mic.tap()
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            for _ in 0..<2 {
                let alert = springboard.alerts.firstMatch
                if alert.waitForExistence(timeout: 3), alert.buttons["Allow"].exists { alert.buttons["Allow"].tap() }
                else if alert.exists, alert.buttons["OK"].exists { alert.buttons["OK"].tap() }
            }
            let running = NSPredicate(format: "value == 'listening'")
            let result = XCTWaiter.wait(for: [expectation(for: running, evaluatedWith: mic)], timeout: 15)
            if result != .completed {
                let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "real-microphone-unavailable-\(cycle)"; shot.lifetime = .keepAlways; add(shot)
                XCTFail(language + ": Real microphone did not enter listening state; inspect permission/audio route/recognizer availability")
                return
            }
            if cycle == 2 {
                app.tabBars.buttons.element(boundBy: 1).tap()
                app.tabBars.buttons.element(boundBy: 0).tap()
            } else { mic.tap() }
            XCTAssertEqual(mic.value as? String, "idle")
        }
        app.terminate()
    }
}
