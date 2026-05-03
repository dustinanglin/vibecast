import XCTest
import SwiftUI
@testable import Vibecast

final class BrandTests: XCTestCase {

    // MARK: - initials(for:)

    func test_initials_twoWords_returnsFirstAndLastInitial() {
        XCTAssertEqual(Brand.initials(for: "Hard Fork"), "HF")
    }

    func test_initials_threeWords_returnsFirstAndLastInitial() {
        XCTAssertEqual(Brand.initials(for: "Conan O'Brien Friend"), "CF")
    }

    func test_initials_singleWord_returnsSingleInitial() {
        XCTAssertEqual(Brand.initials(for: "Radiolab"), "R")
    }

    func test_initials_filtersStopWordTheLeading() {
        XCTAssertEqual(Brand.initials(for: "The Daily"), "D")
    }

    func test_initials_filtersMultipleStopWords() {
        // "Conan O'Brien Needs A Friend" → ["conan", "o'brien", "needs", "friend"]
        // (after dropping "a") → 4 words → first letter of first + last → "CF"
        XCTAssertEqual(Brand.initials(for: "Conan O'Brien Needs A Friend"), "CF")
    }

    func test_initials_digitsRetained() {
        XCTAssertEqual(Brand.initials(for: "99% Invisible"), "9I")
    }

    func test_initials_emptyAfterFilter_returnsQuestionMark() {
        XCTAssertEqual(Brand.initials(for: "The"), "?")
    }

    func test_initials_emptyTitle_returnsQuestionMark() {
        XCTAssertEqual(Brand.initials(for: ""), "?")
    }

    func test_initials_caseInsensitiveStopWordFiltering() {
        XCTAssertEqual(Brand.initials(for: "The Daily"), "D")
        XCTAssertEqual(Brand.initials(for: "THE DAILY"), "D")
        XCTAssertEqual(Brand.initials(for: "the daily"), "D")
    }

    // MARK: - fallbackColor(for:)

    func test_fallbackColor_isStableForSameTitle() {
        let a = Brand.fallbackColor(for: "Hard Fork")
        let b = Brand.fallbackColor(for: "Hard Fork")
        XCTAssertEqual(a, b)
    }

    func test_fallbackColor_distributesAcrossPalette() {
        // 8 distinct titles should map to multiple distinct colors. We don't
        // require all 8 to be unique (hash collisions allowed) but require >=2
        // distinct results across 8 inputs to verify distribution isn't constant.
        let titles = ["Hard Fork", "The Daily", "Radiolab", "99% Invisible",
                      "Planet Money", "Reply All", "Serial", "Conan"]
        let colors: Set<Color> = Set(titles.map { Brand.fallbackColor(for: $0) })
        XCTAssertGreaterThan(colors.count, 1)
    }
}
