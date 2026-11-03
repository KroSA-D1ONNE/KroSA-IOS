import XCTest

final class KroSAGPUTests: XCTestCase {
    func testOpenGPUTestScreenWithoutStartingDeviceRenderer() {
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

        // Simulator CI intentionally does not instantiate GLKit/EAGL:
        // its GLES dispatcher crashes before the app renderer can run.
        // The physical-device EAGL test is started manually on an iPhone.
        let preparedStatus = app.staticTexts["PRUEBA EAGL PREPARADA"]
        XCTAssertTrue(preparedStatus.waitForExistence(timeout: 15),
                      "No apareció el estado previo a iniciar EAGL")

        let startButton = app.buttons["INICIAR PRUEBA EAGL"]
        XCTAssertTrue(startButton.exists,
                      "No apareció el botón para iniciar la prueba EAGL")

        XCTAssertEqual(app.state, .runningForeground,
                       "La aplicación se cerró al abrir la pantalla GPU")
    }
}
