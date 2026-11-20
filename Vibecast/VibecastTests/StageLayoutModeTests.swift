import XCTest
import CoreGraphics
@testable import Vibecast

final class StageLayoutModeTests: XCTestCase {
    private let landscape = CGSize(width: 890, height: 626)
    private let portrait = CGSize(width: 626, height: 890)
    private let outer = CGSize(width: 466, height: 678)

    private func resolve(
        _ pose: DuoPose, _ size: CGSize, regular: Bool = true, fold: Bool = false
    ) -> StageLayoutMode {
        StageLayoutMode.resolve(pose: pose, size: size, isRegularWidth: regular, foldDividesView: fold)
    }

    func test_resolve_notFoldable_isSingle() {
        XCTAssertEqual(resolve(.notFoldable, landscape), .single)
    }

    func test_resolve_closed_isSingle() {
        XCTAssertEqual(resolve(.closed, outer, regular: false), .single)
    }

    func test_resolve_fullyOpenLandscape_isSideBySide() {
        XCTAssertEqual(resolve(.fullyOpen, landscape), .sideBySide)
    }

    func test_resolve_partiallyOpenLandscape_isSideBySide() {
        XCTAssertEqual(resolve(.partiallyOpen, landscape, fold: true), .sideBySide)
    }

    func test_resolve_fullyOpenPortrait_isSingle() {
        XCTAssertEqual(resolve(.fullyOpen, portrait), .single)
    }

    func test_resolve_partiallyOpenPortrait_foldDividesView_isStacked() {
        XCTAssertEqual(resolve(.partiallyOpen, portrait, fold: true), .stacked)
    }

    func test_resolve_partiallyOpenPortrait_foldElsewhere_isSingle() {
        XCTAssertEqual(resolve(.partiallyOpen, CGSize(width: 445, height: 626), regular: false, fold: false), .single)
    }

    func test_resolve_openLandscapeCompactWidth_isSingle() {
        XCTAssertEqual(resolve(.fullyOpen, CGSize(width: 700, height: 626), regular: false), .single)
    }
}
