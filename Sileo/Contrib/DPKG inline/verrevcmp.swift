//
//  verrevcmp.swift
//  Sileo
//
//  Created by CoolStar on 4/17/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation

func isDigit(char: CChar) -> Bool {
    isdigit(Int32(char)) != 0
}

func isAlpha(char: CChar) -> Bool {
    isalpha(Int32(char)) != 0
}

func order(char: CChar) -> Int {
    if isAlpha(char: char) {
        return Int(char)
    } else if char == 126 {
        return -1
    } else if char > 0 {
        return Int(char) + 256
    }
    return 0
}

func verrevcmp(val: ArraySlice<CChar>, ref: ArraySlice<CChar>) -> Int {
    var val = val
    var ref = ref
    while !val.isEmpty || !ref.isEmpty {
        var firstDiff = 0
        var digitPrefix = 0
        for (valchar, refchar) in zip(val, ref) {
            if isDigit(char: valchar) || isDigit(char: refchar) {
                break
            }
            
            let valord = order(char: valchar)
            let reford = order(char: refchar)
            
            if valord != reford {
                return valord - reford
            }
            
            digitPrefix += 1
        }
        val = val.dropFirst(digitPrefix)
        ref = ref.dropFirst(digitPrefix)
        
        digitPrefix = 0
        for valchar in val {
            guard valchar == 48 else {
                break
            }
            digitPrefix += 1
        }
        val = val.dropFirst(digitPrefix)
        
        digitPrefix = 0
        for refchar in ref {
            guard refchar == 48 else {
                break
            }
            digitPrefix += 1
        }
        ref = ref.dropFirst(digitPrefix)
        
        digitPrefix = 0
        for (valchar, refchar) in zip(val, ref) {
            guard isDigit(char: valchar) && isDigit(char: refchar) else {
                break
            }
            if firstDiff == 0 {
                firstDiff = Int(valchar - refchar)
            }
            digitPrefix += 1
        }
        val = val.dropFirst(digitPrefix)
        ref = ref.dropFirst(digitPrefix)
        
        if !val.isEmpty && isDigit(char: val[val.startIndex]) {
            return 1
        }
        if !ref.isEmpty && isDigit(char: ref[ref.startIndex]) {
            return -1
        }
        if firstDiff != 0 {
            return firstDiff
        }
    }
    
    return 0
}
