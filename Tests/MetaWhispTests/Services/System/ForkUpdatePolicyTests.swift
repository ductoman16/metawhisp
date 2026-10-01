import XCTest
@testable import MetaWhisp

final class ForkUpdatePolicyTests: XCTestCase {
    func testForkCannotStartUpstreamUpdater() {
        XCTAssertFalse(AppDelegate.shouldStartUpdater(bundleInfo: ["MetaWhispDisableUpdates": true]))
    }

    func testOrdinaryBuildRetainsUpstreamUpdates() {
        XCTAssertTrue(AppDelegate.shouldStartUpdater(bundleInfo: nil))
        XCTAssertTrue(AppDelegate.shouldStartUpdater(bundleInfo: [:]))
        XCTAssertTrue(AppDelegate.shouldStartUpdater(bundleInfo: ["MetaWhispDisableUpdates": false]))
    }
}
