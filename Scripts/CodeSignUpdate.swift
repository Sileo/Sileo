/*
 CodeSignUpdate.swift
 Created by Chip Jarred on 8/29/20.
 Copyright © 2020 Chip Jarred. All rights reserved.
 
 Based on CodeSignUpdate.sh shell script written by Erik Berglund
 
 The copyright above and the following MIT License apply only to this Swift
 source file and should not be construed as expanding the license or overriding
 the copyright of the creator(s) or owners of the project or source code
 repository containing it.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */


import Foundation

let oidAppleDeveloperIDCA="1.2.840.113635.100.6.2.6"
let oidAppleDeveloperIDApplication="1.2.840.113635.100.6.1.13"
let oidAppleMacAppStoreApplication="1.2.840.113635.100.6.1.9"
let oidAppleWWDRIntermediate="1.2.840.113635.100.6.2.1"

let alphabetStr = "abcdefghijklmnopqrstuvwxyz"
let lowerAlpha = [Character](alphabetStr)
let upperAlpha = [Character](alphabetStr.uppercased())
let digits = [Character]("0123456789")
let devIDChars = upperAlpha + digits
let alphaNumericChars = upperAlpha + lowerAlpha + digits

// -----------------------------------------
struct Environment
{
    // -----------------------------------------
    static subscript(key: String) -> String?
    {
        // -----------------------------------------
        get
        {
            if let value = key.withCString({ getenv($0) }) {
                return String(cString: value)
            }
            return nil
        }
        
        // -----------------------------------------
        set
        {
            key.withCString
            { key in
                if let value = newValue {
                    _ = value.withCString { setenv(key, $0, 1) }
                }
                else { unsetenv(key) }
            }
        }
    }
}

let helpStr =
"""
Place the following lines *BEFORE* CodeSignUpdate in your Run Script phase:
    export MAIN_BUNDLE_ID=<insert your main app bundle id here>
    export HELPER_BUNDLE_ID=<insert your helper bundle id here>
For example, assuming CodeSignUpdate is installed in /usr/local/bin:
    export MAIN_BUNDLE_ID="com.skynet.central"
    export HELPER_BUNDLE_ID="com.skynet.terminator"
    /usr/local/bin/CodeSignUpdate
"""

let bundleIDFormatHelp =
"""
Bundle identifiers should be in reverse domain format.  For example:
    com.skynet.terminator
    com.github.paranoidMacDev.WhosOutToGetYouApp
"""

// -------------------------------------
func emitError(_ msg: String) -> Never
{
    print("error: \(msg)")
    exit(1)
}

// -------------------------------------
func environmentVarNotSet(_ variable: String, addHelp: Bool = false) -> Never
{
    let message = "\(variable) environment variable not set\n\(helpStr)"
        + (addHelp ? "\n\(helpStr)" : "")
    
    emitError(message)
}

// -------------------------------------
func getBundleIDFrom(_ environmentVariable: String) -> String
{
    guard let bundleID = Environment[environmentVariable] else {
        environmentVarNotSet(environmentVariable, addHelp: true)
    }
    
    let bundleIDChars = alphaNumericChars + ["."]
    
    guard bundleID.count > 1 else {
        emitError("Bundle ID is empty\n\(bundleIDFormatHelp)")
    }
    
    guard bundleID.reduce(true, { $0 && bundleIDChars.contains($1) }) else
    {
        emitError(
            "Bundle ID contains illegal characters: \(bundleID)\n"
            + "\(bundleIDFormatHelp)"
        )
    }
    
    guard bundleID.first! != "." && bundleID.last! != "." else
    {
        emitError(
            "Bundle ID must not start or end with period: \(bundleID)\n"
            + "\(bundleIDFormatHelp)"
        )
    }
    
    return bundleID
}


let bundleIdentifierApplication = getBundleIDFrom("MAIN_BUNDLE_ID")
let bundleIdentifierHelper = getBundleIDFrom("HELPER_BUNDLE_ID")

guard let infoPListFile = Environment["INFOPLIST_FILE"] else {
    environmentVarNotSet("INFOPLIST_FILE")
}

var infoPlist: [String: AnyObject] =
{
    let pListURL = URL(fileURLWithPath: infoPListFile)
    guard let pListDict = NSDictionary(contentsOf: pListURL)
        as? Dictionary<String, AnyObject>
    else {
        emitError("Unable to read plist data from \(infoPListFile)")
    }
    return pListDict
}()

let target: String = infoPlist["UIMainStoryboardFile"] as? String == "Main"
    ? "application"
    : "helper"

// -------------------------------------
func isValidDeveloperID<S: StringProtocol>(_ s: S) -> Bool
{
    guard s.count == 10 else { return false }
    return s.reduce(true) { $0 && devIDChars.contains($1) }
}

// -------------------------------------
func isValidDeveloperCN(_ s: String, withPrefix prefix: String) -> Bool
{
    // +4 accounts for 2 spaces, plus open and close parentheses
    guard s.hasPrefix(prefix), s.count > prefix.count + 4 else { return false }
    
    guard let openParen = s.lastIndex(of: "(") else { return false }
    guard let closeParen = s.lastIndex(of: ")") else { return false }
    
    guard s.distance(from: closeParen, to: s.endIndex) == 1 else {
        return false
    }
    
    guard s.distance(from: openParen, to: closeParen) == 11 else {
        return false
    }
    
    return isValidDeveloperID(s[s.index(after: openParen)..<closeParen])
}

// -------------------------------------
func isValidDeveloperCN(_ s: String) -> Bool
{
    let appleDeveloper = "Apple Development:"
    let macDeveloper = "Mac Developer:"
    
    if isValidDeveloperCN(s, withPrefix: appleDeveloper) { return true }
    if isValidDeveloperCN(s, withPrefix: macDeveloper) { return true }
    
    return false
}

// -------------------------------------
func appendAppleGeneric(to s: inout String) {
    s += "anchor apple generic"
}

// -------------------------------------
func appendAppleDeveloperID(to s: inout String)
{
    let exists = "/* exists */"
    
    s += "certificate leaf[field.\(oidAppleMacAppStoreApplication)] "
        + exists
        + " or certificate 1[field.\(oidAppleDeveloperIDCA)] "
        + exists
        + " and certificate leaf[field.\(oidAppleDeveloperIDApplication)] "
        + exists
}

// -------------------------------------
func appendAppleMacDeveloper(to s: inout String) {
    s += "certificate 1[field.\(oidAppleWWDRIntermediate)]"
}

// -------------------------------------
func appendApplicationBundleIdentifier(to s: inout String) {
    s += "identifier \"\(bundleIdentifierApplication)\""
}

// -------------------------------------
func appendHelperBundleIdentifier(to s: inout String) {
    s += "identifier \"\(bundleIdentifierHelper)\""
}

// -------------------------------------
func appendDeveloperID(to s: inout String)
{
    guard let devTeamID = Environment["DEVELOPMENT_TEAM"] else {
        environmentVarNotSet("DEVELOPMENT_TEAM")
    }
    
    guard isValidDeveloperID(devTeamID) else {
        emitError("Invalid Development Team Identifier: \(devTeamID)")
    }
    
    s += "certificate leaf[subject.OU] = \(devTeamID)"
}

// -------------------------------------
func appendMacDeveloper(to s: inout String)
{
    guard let macDeveloperCN = Environment["EXPANDED_CODE_SIGN_IDENTITY_NAME"]
    else
    {
        environmentVarNotSet("EXPANDED_CODE_SIGN_IDENTITY_NAME")
    }
    
    guard isValidDeveloperCN(macDeveloperCN) else {
        emitError("Invalid Mac Developer CN: \(macDeveloperCN)")
    }
    
    s += "certificate leaf[subject.CN] = \"\(macDeveloperCN)\""
}

// -------------------------------------
func updateSMPriviledgedExecutables(
    in plistDict: inout [String: AnyObject],
    with s: String)
{
    assert(target == "application")
    guard let prodBundleID = Environment["PRODUCT_BUNDLE_IDENTIFIER"] else {
        environmentVarNotSet("PRODUCT_BUNDLE_IDENTIFIER")
    }
    
    guard prodBundleID == bundleIdentifierApplication else
    {
        emitError(
            "PRODUCT_BUNDLE_IDENTIFIER does not match MAIN_BUNDLE_ID\n"
            + "  PRODUCT_BUNDLE_IDENTIFIER = \(prodBundleID)\n"
            + "             MAIN_BUNDLE_ID = \(bundleIdentifierApplication)"
        )
    }
    
    plistDict.removeValue(forKey: "SMPrivilegedExecutables")
    let newExecutables: [String: String] = [bundleIdentifierHelper: s]
    plistDict["SMPrivilegedExecutables"] = newExecutables as NSDictionary
}

// -------------------------------------
func updateSMAuthorizedClients(
    in plistDict: inout [String: AnyObject],
    with s: String)
{
    assert(target == "helper")
    guard let prodBundleID = plistDict["CFBundleIdentifier"] as? String else
    {
        emitError(
            "Helper info property list, \(infoPListFile), is missing "
            + "\"CFBundleIdentifier\" key, or it not a string"
        )
    }
    guard prodBundleID == bundleIdentifierHelper else
    {
        emitError(
            "Bundle id in info propery list, \(infoPListFile), does not"
            + " match HELPER_BUNDLE_ID\n"
            + "     plists CFBundleIdentifier = \(prodBundleID)\n"
            + "              HELPER_BUNDLE_ID = \(bundleIdentifierHelper)"
        )
    }
    
    guard let prodBundleName = plistDict["CFBundleName"] as? String else
    {
        emitError(
            "Helper info property list, \(infoPListFile), is missing "
            + "\"CFBundleName\" key, or it not a string"
        )
    }
    guard prodBundleName == bundleIdentifierHelper else
    {
        emitError(
            "Bundle name in info propery list, \(infoPListFile), does "
            + "not match HELPER_BUNDLE_ID\n"
            + "     plists CFBundleName = \(prodBundleName)\n"
            + "        HELPER_BUNDLE_ID = \(bundleIdentifierHelper)"
        )
    }
    
    plistDict.removeValue(forKey: "SMAuthorizedClients")
    let newClients: [String] = [s]
    plistDict["SMAuthorizedClients"] = newClients as NSArray
}

guard let action = Environment["ACTION"] else {
    environmentVarNotSet("ACTION")
}

var appString = ""
var helperString = ""

switch action
{
    case "build":
        appendApplicationBundleIdentifier(to: &appString)
        appString += " and "
        appendAppleGeneric(to: &appString)
        appString += " and "
        appendMacDeveloper(to: &appString)
        appString += " and "
        appendAppleMacDeveloper(to: &appString)
        appString += " /* exists */"
    
        appendHelperBundleIdentifier(to: &helperString)
        helperString += " and "
        appendAppleGeneric(to: &helperString)
        helperString += " and "
        appendMacDeveloper(to: &helperString)
        helperString += " and "
        appendAppleMacDeveloper(to: &helperString)
        helperString += " /* exists */"
    
    case "install":
        appendAppleGeneric(to: &appString)
        appString += " and "
        appendApplicationBundleIdentifier(to: &appString)
        appString += " and "
        appendAppleDeveloperID(to: &appString)
        appString += " and "
        appendDeveloperID(to: &appString)
    
        appendAppleGeneric(to: &helperString)
        appString += " and "
        appendHelperBundleIdentifier(to: &helperString)
        appString += " and "
        appendAppleDeveloperID(to: &helperString)
        appString += " and "
        appendDeveloperID(to: &helperString)

    default:
        emitError("Unknown Xcode Action: \(action)")
}

if target == "helper" {
    updateSMAuthorizedClients(in: &infoPlist, with: appString)
}
else if target == "application" {
    updateSMPriviledgedExecutables(in: &infoPlist, with: helperString)
}
else { emitError("Unknown Target: \(target)") }

(infoPlist as NSDictionary).write(toFile: infoPListFile, atomically: true)
