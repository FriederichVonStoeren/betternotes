import XCTest

/// Opens the app in the simulator, draws with a finger in every mode and keeps screenshots.
/// CI exports them as the artifact "ui-screenshots" so that layout can be checked without a device.
final class ScreenshotTests: XCTestCase {
    private func launch(language: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))"]
        app.launch()
        XCTAssertTrue(app.staticTexts["hud"].waitForExistence(timeout: 20))
        return app
    }

    private func draw(in app: XCUIApplication) {
        let window = app.windows.firstMatch
        let points = [(0.2, 0.35), (0.45, 0.6), (0.7, 0.35)].map {
            window.coordinate(withNormalizedOffset: CGVector(dx: $0.0, dy: $0.1))
        }
        points[0].press(forDuration: 0.05, thenDragTo: points[1])
        points[1].press(forDuration: 0.05, thenDragTo: points[2])
    }

    private func keepScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testDrawInEveryMode() {
        let app = launch(language: "en")
        // PencilKit keeps its strokes to itself; Custom and Hybrid each add two to our engine.
        for (mode, strokes) in [("PencilKit", 0), ("Custom", 2), ("Hybrid", 4)] {
            app.segmentedControls.buttons[mode].tap()
            draw(in: app)
            keepScreenshot("en-\(mode)")
            XCTAssertTrue(app.staticTexts["hud"].label.contains("\(strokes) strokes"), "\(mode): \(app.staticTexts["hud"].label)")
        }
        app.buttons["clear"].tap()
        XCTAssertTrue(app.staticTexts["hud"].label.contains("0 strokes"))
        keepScreenshot("en-cleared")
    }

    func testGerman() {
        let app = launch(language: "de")
        XCTAssertTrue(app.segmentedControls.buttons["Eigene Engine"].exists)
        draw(in: app)
        XCTAssertTrue(app.staticTexts["hud"].label.contains("2 Striche"), app.staticTexts["hud"].label)
        keepScreenshot("de-Custom")
    }
}
