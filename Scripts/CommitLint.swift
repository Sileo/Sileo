//
//  CommitLint.swift
//  Sileo
//
//  Created by Aarnav Tale on 12/27/22.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

let pattern = "^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test){1}(!)?: (.*)"
let regex = try Regex(pattern)

let input = CommandLine.arguments[1]
if input.firstMatch(of: regex) != nil {
    exit(0)
} else {
    print("[x] Commit Failed! Please use conventional commits.")
    print("[x] https://www.conventionalcommits.org/en/v1.0.0/")
    exit(1)
}
