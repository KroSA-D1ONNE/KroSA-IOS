import XCTest

final class KroSAGPUTests: XCTestCase {
    func testOpenAndRunGPUTestWithoutCrashing() {
        let app = XCUIApplication()
        app.launch()

        let gpuButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[cd] %@", "GPU")
        ).firstMatch
        XCTAssertTrue(gpuButton.waitForExistence(timeout: 20),
                      "No apareció el botón para abrir el test de GPU")

        gpuButton.tap()

        let testTitle = app.staticTexts["KroSA · GRAPHICS TEST"]
        XCTAssertTrue(testTitle.waitForExistence(timeout: 15),
                      "La pantalla de test GPU no llegó a mostrarse")

        let geometryStatus = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[cd] %@", "LIBRW GEOMETRY:")
        ).firstMatch
        XCTAssertTrue(geometryStatus.waitForExistence(timeout: 30),
                      "El renderer no informó el resultado de geometría")
        XCTAssertTrue(app.exists, "La aplicación se cerró durante el test GPU")
    }
}
