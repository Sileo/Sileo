//
//  PackageProtocol.swift
//  Sileo
//
//  Created by Amy While on 23/03/2023.
//  Copyright © 2023 Sileo Team. All rights reserved.
//

import Foundation

protocol PackageProtocol: Hashable, Equatable, Comparable {
    
    var package: String { get }
    var version: String { get }
    
}

func ==(lhs: some PackageProtocol, rhs: some PackageProtocol) -> Bool {
    lhs.package == rhs.package && lhs.version == rhs.version
}

func <(lhs: some PackageProtocol, rhs: some PackageProtocol) -> Bool {
    DpkgWrapper.isVersion(rhs.version, greaterThan: lhs.version)
}

func >(lhs: some PackageProtocol, rhs: some PackageProtocol) -> Bool {
    DpkgWrapper.isVersion(lhs.version, greaterThan: rhs.version)
}

func >=(lhs: some PackageProtocol, rhs: some PackageProtocol) -> Bool {
    if lhs.version == rhs.version {
        return true
    }
    return lhs > rhs
}

func <=(lhs: some PackageProtocol, rhs: some PackageProtocol) -> Bool {
    if lhs.version == rhs.version {
        return true
    }
    return lhs < rhs
}

extension PackageProtocol {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(package)
        hasher.combine(version)
    }
    
}

