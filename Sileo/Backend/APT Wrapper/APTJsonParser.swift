//
//  APTJsonParser.swift
//  Sileo
//
//  Created by Aarnav Tale on 6/28/21.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

enum APTParserErrors: LocalizedError {
    case missingSileoConf
    case blankRequest
    case failedDataEncoding
    case blankJsonOutput(error: String)
    
    var errorDescription: String? {
        switch self {
        case .blankJsonOutput(let error): return "APT was unable to find this package. Please try refreshing your sources\n \(error)"
        case .failedDataEncoding: return "APT returned an invalid response that cannot be parsed."
        case .missingSileoConf: return "Your Sileo install is incomplete. Please reinstall"
        case .blankRequest: return "Internal Error: Blank Request sent for packages"
        }
    }
}

struct APTOutput {
    var operations = [APTOperation]()
    var conflicts = [APTBrokenPackage]()
}

// This is for parsing a full JSON Object
struct RawAPTOutput: Decodable {
    enum CodingKeys: String, CodingKey {
        case operations
        case brokenPackages
    }

    var operations: [APTOperation]?
    var brokenPackages: ErrorParserWrapper?

    // This bit above and below are here so that the keys can be optional
    // Essentially, APT either gives an "operations" or "brokenPackages" key
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        self.operations = try? values.decodeIfPresent([APTOperation].self, forKey: .operations)
        self.brokenPackages = try? values.decodeIfPresent(ErrorParserWrapper.self, forKey: .brokenPackages)
    }
}

struct APTOperation: Decodable {
    enum CodingKeys: String, CodingKey {
        case packageID = "Package"
        case version = "Version"
        case type = "Type"
        case release = "Release"
    }

    enum OperationType: String, Decodable {
        case install = "Inst"
        case configure = "Conf"
        case remove = "Remv"
        case purge = "Purg"
    }

    let packageID: String
    let version: String
    let type: OperationType
    let release: String?
}

struct APTBrokenPackage: Decodable {
    struct ConflictingPackage: Decodable {

        // swiftlint:disable nesting
        enum Conflict: String, Decodable {
            case preDepends = "Pre-Depends"
            case recommends = "Recommends"
            case conflicts = "Conflicts"
            case replaces = "Replaces"
            case depends = "Depends"
        }

        // swiftlint:disable nesting
        enum CodingKeys: String, CodingKey {
            case package = "Package"
            case conflict = "Type"
        }

        let package: String
        let conflict: Conflict
    }

    let packageID: String
    let conflictingPackages: [ConflictingPackage]
}

struct ErrorParserWrapper: Decodable {
    var brokenPackages: [APTBrokenPackage]

    // This allows us to have custom JSON keys
    // APT returns this for brokenPackages
    struct PackageIDKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: PackageIDKey.self)
        var brokenPackages = [APTBrokenPackage]()

        for package in container.allKeys {
            // These are the individual brokenPackages given by APT (It's a double nested array because of the way the JSON patch is)
            let wrappedConflictingPackages = try container.decode([[APTBrokenPackage.ConflictingPackage]].self, forKey: package)

            // ErrorParserWrapper is merely used to create an APTBrokenPackage
            // That's why the package is created manually, to prevent unnecessary data nesting
            for conflictingPackages in wrappedConflictingPackages {
                let brokenPackage = APTBrokenPackage(packageID: package.stringValue, conflictingPackages: conflictingPackages)
                brokenPackages.append(brokenPackage)
            }
        }

        self.brokenPackages = brokenPackages
    }
}

extension APTWrapper {
    // APT syntax: a- = remove a; b = install b
    public class func operationList(installList: [DownloadPackage], removeList: [DownloadPackage]) throws -> APTOutput {
        // Error check stuff
        guard let configPath = Bundle.main.path(forResource: "sileo-apt", ofType: "conf") else {
            throw APTParserErrors.missingSileoConf
        }

        guard !(installList.isEmpty && removeList.isEmpty) else {
            // What the hell are you passing, requesting an operationList without any packages?
            throw APTParserErrors.blankRequest
        }

        let queryArguments = [
            "-sqf", "--allow-remove-essential", "--allow-change-held-packages",
            "--allow-downgrades", "-oquiet::NoUpdate=true", "-oApt::Get::HideAutoRemove=true",
            "-oquiet::NoProgress=true", "-oquiet::NoStatistic=true", "-c", configPath,
            "-oAcquire::AllowUnsizedPackages=true", "-oAPT::Get::Show-User-Simulation-Note=False",
            "-oAPT::Format::for-sileo=true", "-oAPT::Format::JSON=true", "install", "--reinstall"
        ]

        var packageOperations: [String] = []
        for downloadPackage in installList {
            // The downloadPackage.package.package is the deb path on local installs
            // if it has a / that means it's the path which is a local install
            if downloadPackage.package.package.contains("/") {
                // APT will take the raw package path for install
                packageOperations.append(downloadPackage.package.package)
            } else {
                // Force the exact version of the package we downloaded from the repository
                packageOperations.append("\(downloadPackage.package.packageID)=\(downloadPackage.package.version)")
            }
        }

        for downloadPackage in removeList {
            // Adding '-' after the packageID will query for removal
            packageOperations.append("\(downloadPackage.package.packageID)-")
        }

        // APT spawn stuff
        var aptStdout = ""
        var aptError = ""

        (_, aptStdout, aptError) = spawn(command: CommandPath.aptget, args: ["apt-get"] + queryArguments + packageOperations)
        let aptJsonOutput = try normalizeAptOutput(rawOutput: aptStdout, error: aptError)
        
        return aptJsonOutput
    }

    // We need to take multiple outputs and make it a full JSON object in some cases, while others we can just serialize the full struct
    private class func normalizeAptOutput(rawOutput: String, error: String) throws -> APTOutput {
        let decoder = JSONDecoder()
        var aptOutput = APTOutput()

        // Detect what type of JSON output we are working with
        // If it's separate JSON, we will serialize immediately
        // If it's a full JSON object, we will parse it later
        for rawLine in rawOutput.components(separatedBy: "\n") {
            let cleanLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            // Seperated JSON Objects parsing (Procursus)
            if cleanLine.hasPrefix("{") && cleanLine.hasSuffix("}") {
                guard let data = cleanLine.data(using: .utf8) else {
                    // What the actual hell, oh well..
                    throw APTParserErrors.failedDataEncoding
                }

                if let operation = try? decoder.decode(APTOperation.self, from: data) {
                    aptOutput.operations.append(operation)
                }

                if let error = try? decoder.decode(ErrorParserWrapper.self, from: data) {
                    aptOutput.conflicts += error.brokenPackages
                }
            }
        }

        // If there was no decodeable output, we need to parse as one big object (Elucubratus)
        if aptOutput.conflicts.isEmpty && aptOutput.operations.isEmpty {
            let cleanOutput = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: "")

            // We need a substring of the JSON object only
            guard let openingBracket = cleanOutput.firstIndex(of: "{"),
                  let closingBracket = cleanOutput.lastIndex(of: "}") else {
                throw APTParserErrors.blankJsonOutput(error: error)
            }

            let jsonObject = cleanOutput[openingBracket..<closingBracket]
                // These are normalized to have easier JSON parsing
                .replacingOccurrences(of: "CandidateVersion", with: "Version")
                .replacingOccurrences(of: "CurrentVersion", with: "Version")
                .appending("}") // Appended this because we cut it off in our substring

            guard let data = jsonObject.data(using: .utf8) else {
                throw APTParserErrors.failedDataEncoding
            }

            let rawOutput = try decoder.decode(RawAPTOutput.self, from: data)

            if let operations = rawOutput.operations {
                aptOutput.operations += operations
            }

            if let parsedError = rawOutput.brokenPackages {
                aptOutput.conflicts += parsedError.brokenPackages
            }
        }

        return aptOutput
    }
}
