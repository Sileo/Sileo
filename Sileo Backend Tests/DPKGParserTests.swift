//
//  DPKGParserTests.swift
//  Sileo Backend Tests
//
//  Created by Amy While on 23/03/2023.
//  Copyright © 2023 Sileo Team. All rights reserved.
//

import XCTest
@testable import Sileo

final class DPKGParserTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAMaintainerParser() throws {
        let case1 = "Amy While <me@anamy.gay>"
        let case2 = "Amy While"
        let case3 = "Amy While <me@anamy.gay"
        
        let case1Maintainer = Maintainer(string: case1)
        XCTAssert(case1Maintainer.name == "Amy While" && case1Maintainer.email == "me@anamy.gay", "Failed to parse \(case1)")
        let case2Maintainer = Maintainer(string: case2)
        XCTAssert(case2Maintainer.name == "Amy While" && case2Maintainer.email == nil, "Failed to parse \(case2)")
        let case3Maintainer = Maintainer(string: case3)
        XCTAssert(case3Maintainer.name == "Amy While" && case3Maintainer.email == nil, "Failed to parse \(case3), got: \(dump(case3Maintainer))")
    }

}
