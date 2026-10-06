import CoreGraphics
import Testing
@testable import Speak2Kit

struct ScreenRegionGeometryTests {
    private let display = CGSize(width: 1440, height: 900)

    @Test func convertsBottomLeftToTopLeft() {
        let rect = ScreenRegionGeometry.captureRect(selection: CGRect(x: 100, y: 200, width: 300, height: 150), displaySize: display)
        #expect(rect == CGRect(x: 100, y: 550, width: 300, height: 150))
    }

    @Test func preservesTopEdge() {
        let rect = ScreenRegionGeometry.captureRect(selection: CGRect(x: 0, y: 800, width: 200, height: 100), displaySize: display)
        #expect(rect == CGRect(x: 0, y: 0, width: 200, height: 100))
    }

    @Test func clipsDragToDisplay() {
        let rect = ScreenRegionGeometry.captureRect(selection: CGRect(x: -20, y: -30, width: 100, height: 100), displaySize: display)
        #expect(rect == CGRect(x: 0, y: 830, width: 80, height: 70))
    }

    @Test func normalizesReverseDrag() {
        let rect = ScreenRegionGeometry.captureRect(selection: CGRect(x: 400, y: 350, width: -300, height: -150), displaySize: display)
        #expect(rect == CGRect(x: 100, y: 550, width: 300, height: 150))
    }

    @Test func rejectsClicksAndOffscreenSelections() {
        #expect(ScreenRegionGeometry.captureRect(selection: CGRect(x: 10, y: 10, width: 1, height: 30), displaySize: display) == nil)
        #expect(ScreenRegionGeometry.captureRect(selection: CGRect(x: 1500, y: 10, width: 100, height: 100), displaySize: display) == nil)
    }
}
