import XCTest

#if os(Linux) || os(FreeBSD) || os(Windows) || os(Android)
    @testable import SwiftConfigsTests

    XCTMain([
        testCase(SwiftConfigsTests.all),
    ])
#endif
