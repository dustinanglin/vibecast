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
        StageLayoutMode.resolve(pose: pose, size: size, isRegularWidth: regular, horizontalFoldDividesView: fold)
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

    // MARK: fold direction

    func test_horizontalFold_bandAcrossMiddle_isTrue() {
        let fold = CGRect(x: 0, y: 435, width: 626, height: 20)
        XCTAssertTrue(StageLayoutMode.horizontalFoldDivides(portrait, divisions: [fold]))
    }

    func test_horizontalFold_zeroHeightLineAcrossMiddle_isTrue() {
        let fold = CGRect(x: 0, y: 445, width: 626, height: 0)
        XCTAssertTrue(StageLayoutMode.horizontalFoldDivides(portrait, divisions: [fold]))
    }

    func test_horizontalFold_noDivisions_isFalse() {
        XCTAssertFalse(StageLayoutMode.horizontalFoldDivides(portrait, divisions: []))
    }

    /// Split View beside another app in landscape: the window is one half of
    /// the inner display and the fold runs down its edge.
    func test_horizontalFold_verticalFoldAtWindowEdge_isFalse() {
        let half = CGSize(width: 435, height: 626)
        let fold = CGRect(x: 435, y: 0, width: 20, height: 626)
        XCTAssertFalse(StageLayoutMode.horizontalFoldDivides(half, divisions: [fold]))
    }

    func test_horizontalFold_verticalFoldThroughWindow_isFalse() {
        let window = CGSize(width: 600, height: 626)
        let fold = CGRect(x: 435, y: 0, width: 20, height: 626)
        XCTAssertFalse(StageLayoutMode.horizontalFoldDivides(window, divisions: [fold]))
    }

    func test_horizontalFold_bandAtTopOrBottomEdge_isFalse() {
        let top = CGRect(x: 0, y: -20, width: 626, height: 20)
        let bottom = CGRect(x: 0, y: 890, width: 626, height: 20)
        XCTAssertFalse(StageLayoutMode.horizontalFoldDivides(portrait, divisions: [top, bottom]))
    }
}
