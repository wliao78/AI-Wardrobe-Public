import XCTest

final class WardrobeUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testOfflineClosetEditEnlargeFavoriteAndCameraFallback() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["look.saveLook"].waitForExistence(timeout: 10))
        app.buttons["look.saveLook"].tap()
        for _ in 0..<4 { app.buttons["look.newLook"].tap() }
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.buttons["closet.item.white-oxford"].tap()
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
            app.buttons["chat.send"].tap()
            XCTAssertTrue(app.staticTexts["A casual outfit today"].waitForExistence(timeout: 5), language)
            XCTAssertTrue(app.staticTexts["A casual outfit today"].isHittable, language + " latest conversation must be visible")
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

    @MainActor func testSevenLanguagesRealMicrophoneLifecycle() {
        for (language, region) in [("en","en_US"),("zh-Hans","zh_CN"),("zh-Hant","zh_TW"),("ja","ja_JP"),("fr","fr_FR"),("de","de_DE"),("es","es_ES")] {
            checkRealMicrophone(language: language, region: region)
        }
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
