//
//  APTWrapper.swift
//  Sileo
//
//  Created by CoolStar on 8/24/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class APTWrapper {
    static let sileoFD = 6
    static let cydiaCompatFd = 6
    static let debugFD = 11
    
    public enum FINISH: Int {
        case back = 0,
        uicache = 1,
        reopen = 2,
        restart = 3,
        reload = 4,
        reboot = 5
    }
    
    static let GNUPGPREFIX = "[GNUPG:]"
    static let GNUPGBADSIG = "[GNUPG:] BADSIG"
    static let GNUPGERRSIG = "[GNUPG:] ERRSIG"
    static let GNUPGNOPUBKEY = "[GNUPG:] NO_PUBKEY"
    static let GNUPGVALIDSIG = "[GNUPG:] VALIDSIG"
    static let GNUPGGOODSIG = "[GNUPG:] GOODSIG"
    static let GNUPGEXPKEYSIG = "[GNUPG:] EXPKEYSIG"
    static let GNUPGEXPSIG = "[GNUPG:] EXPSIG"
    static let GNUPGREVKEYSIG = "[GNUPG:] REVKEYSIG"
    static let GNUPGNODATA = "[GNUPG:] NODATA"
    static let APTKEYWARNING = "[APTKEY:] WARNING"
    static let APTKEYERROR = "[APTKEY:] ERROR"
    
    enum DigestState {
        case untrusted,
        weak,
        trusted
    }
    
    struct Digest {
        let state: DigestState
        let name: String
    }
    
    static let digests: [Digest] = [
        Digest(state: .untrusted, name: "Invalid Digest"),
        Digest(state: .untrusted, name: "MD5"),
        Digest(state: .untrusted, name: "SHA1"),
        Digest(state: .untrusted, name: "RIPE-MD/160"),
        Digest(state: .untrusted, name: "Reserved digest"),
        Digest(state: .untrusted, name: "Reserved digest"),
        Digest(state: .untrusted, name: "Reserved digest"),
        Digest(state: .untrusted, name: "Reserved digest"),
        Digest(state: .trusted, name: "SHA256"),
        Digest(state: .trusted, name: "SHA384"),
        Digest(state: .trusted, name: "SHA512"),
        Digest(state: .trusted, name: "SHA224")
    ]
    
    class func dictionaryOfScannedApps() -> [String: Int64] {
        var dictionary: [String: Int64] = [:]
        let fileManager = FileManager.default
        
        guard let apps = try? fileManager.contentsOfDirectory(atPath: "/Applications") else {
            return dictionary
        }
        
        for app in apps {
            let infoPlist = String(format: "/Applications/%@/Info.plist", app)
            
            guard let attr = try? fileManager.attributesOfItem(atPath: infoPlist) else {
                continue
            }
            
            let fileNumber = attr[FileAttributeKey.systemFileNumber] as? Int64
            dictionary[app] = fileNumber
        }
        return dictionary
    }
    
    //APT syntax: a- = remove a; b = install b
    public class func packageOperations(installs: [DownloadPackage], removals: [DownloadPackage]) -> [String: [[String: Any]]] {
        var arguments = ["-sqf", "--allow-remove-essential",
                         "--allow-downgrades", "-oquiet::NoUpdate=true",
                         "-oApt::Get::HideAutoRemove=true", "-oquiet::NoProgress=true",
                         "-oquiet::NoStatistic=true", "-c", Bundle.main.path(forResource: "sileo-apt", ofType: "conf") ?? "",
                         "-oAPT::Get::Show-User-Simulation-Note=False",
                         "-oAPT::Format::for-sileo=true", "-oAPT::Format::JSON=true",
                         "install", "--reinstall"]
        for package in installs {
            if package.package.package.contains("/") {
                arguments.append(package.package.package)
            } else {
                arguments.append(package.package.package + "=" + package.package.version)
            }
        }
        for package in removals {
            arguments.append(package.package.package + "-")
        }
        
        var status: Int = 0
        var aptOutput = ""
        var aptErrorOutput = ""
        
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        if installs.count + removals.count > 1 {
            fatalError("Only have sample data for at most 1 package, sorry :(")
        }
        // swiftlint:disable line_length
        if !installs.isEmpty && installs[0].package.package == "org.coolstar.betterpowerdown" {
            aptOutput = "{\"Type\":\"Inst\",\"Package\":\"org.coolstar.libclassictelephonyui\",\"Version\":\"1.2-3\",\"Release\":\"BigBoss+:0.9/stable [iphoneos-arm]\"}\n{\"Type\":\"Inst\",\"Package\":\"org.coolstar.betterpowerdown\",\"Version\":\"1.4.0\",\"Release\":\"BigBoss+:0.9/stable [iphoneos-arm]\"}"
        } else if !installs.isEmpty && installs[0].package.package == "com.ikilledappl3.sareth" {
            aptOutput = "Some packages could not be installed. This may mean that you have\nrequested an impossible situation or if you are using the unstable\ndistribution that some required packages have not yet been created\nor been moved out of Incoming.\nThe following information may help to resolve the situation:\n\nThe following packages have unmet dependencies:\n{\"com.ikilledappl3.sareth\":[[{\"Reason\":\"11.3.1 is to be installed\",\"Package\":\"firmware\",\"Type\":\"Depends\",\"VersionSummary\":\">= 12.0\"}]]}"
            aptErrorOutput = "E: Unable to correct problems, you have held broken packages."
        } else if !removals.isEmpty && removals[0].package.package == "bash" {
            aptOutput = "{\"Type\":\"Remv\",\"Package\":\"cydia-lproj\",\"Version\":\"1.1.12\"}\n{\"Type\":\"Remv\",\"Package\":\"cydia\",\"Version\":\"2.0-sileo\"}\n{\"Type\":\"Remv\",\"Package\":\"org.coolstar.sileo\",\"Version\":\"0.1b6\"}\n{\"Type\":\"Remv\",\"Package\":\"apt7\",\"Version\":\"1.4.8\"}\n{\"Type\":\"Remv\",\"Package\":\"apt7-key\",\"Version\":\"1.4.8\"}\n{\"Type\":\"Remv\",\"Package\":\"apt7-lib\",\"Version\":\"1.4.8-1\"}\n{\"Type\":\"Remv\",\"Package\":\"base\",\"Version\":\"1-4\"}\n{\"Type\":\"Remv\",\"Package\":\"com.linusyang.localeutf8\",\"Version\":\"1.0-1\"}\n{\"Type\":\"Remv\",\"Package\":\"coreutils\",\"Version\":\"8.29-1\"}\n{\"Type\":\"Remv\",\"Package\":\"profile.d\",\"Version\":\"0-2\"}\n{\"Type\":\"Remv\",\"Package\":\"system-cmds\",\"Version\":\"790\"}\n{\"Type\":\"Remv\",\"Package\":\"firmware-sbin\",\"Version\":\"0-1\"}\n{\"Type\":\"Remv\",\"Package\":\"dpkg\",\"Version\":\"1.18.24\"}\n{\"Type\":\"Remv\",\"Package\":\"findutils\",\"Version\":\"4.6\"}\n{\"Type\":\"Remv\",\"Package\":\"bash\",\"Version\":\"4.4.18\"}\n{\"Type\":\"Remv\",\"Package\":\"berkeleydb\",\"Version\":\"6.2.23\"}\n{\"Type\":\"Remv\",\"Package\":\"com.tigisoftware.filza\",\"Version\":\"3.5.2-1\"}\n{\"Type\":\"Remv\",\"Package\":\"curl\",\"Version\":\"7.59.0-1\"}\n{\"Type\":\"Remv\",\"Package\":\"darwintools\",\"Version\":\"1-6\"}\n{\"Type\":\"Remv\",\"Package\":\"debianutils\",\"Version\":\"4.8.4\"}\n{\"Type\":\"Remv\",\"Package\":\"gnupg\",\"Version\":\"1.4.22\"}\n{\"Type\":\"Remv\",\"Package\":\"tar\",\"Version\":\"1.30\"}\n{\"Type\":\"Remv\",\"Package\":\"lzma\",\"Version\":\"5.2.3\"}\n{\"Type\":\"Remv\",\"Package\":\"gzip\",\"Version\":\"1.8\"}\n{\"Type\":\"Remv\",\"Package\":\"grep\",\"Version\":\"3.1\"}\n{\"Type\":\"Remv\",\"Package\":\"nano\",\"Version\":\"2.9.7\"}\n{\"Type\":\"Remv\",\"Package\":\"vim\",\"Version\":\"8.0.1848\"}\n{\"Type\":\"Remv\",\"Package\":\"ncurses\",\"Version\":\"6.1\"}\n{\"Type\":\"Remv\",\"Package\":\"nghttp2\",\"Version\":\"1.31.0\"}\n{\"Type\":\"Remv\",\"Package\":\"openssh\",\"Version\":\"7.6p1-4\"}\n{\"Type\":\"Remv\",\"Package\":\"org.coolstar.cctools\",\"Version\":\"895\"}\n{\"Type\":\"Remv\",\"Package\":\"wget\",\"Version\":\"1.19\"}\n{\"Type\":\"Remv\",\"Package\":\"openssl\",\"Version\":\"1.0.2n\"}\n{\"Type\":\"Remv\",\"Package\":\"sed\",\"Version\":\"4.2.2\"}\n{\"Type\":\"Remv\",\"Package\":\"shell-cmds\",\"Version\":\"203\"}\n{\"Type\":\"Remv\",\"Package\":\"socat\",\"Version\":\"1.7.2.3\"}"
        } else if !installs.isEmpty || !removals.isEmpty {
            fatalError("Package ID doesn't match sample data (org.coolstar.betterpowerdown, com.ikilledappl3.sareth, or bash).")
        }
        // swiftlint:enable line_length
        #else
        if installs.isEmpty && removals.isEmpty {
            aptOutput = ""
        } else {
            (status, aptOutput, aptErrorOutput) = spawn(command: "/usr/bin/apt-get", args: ["apt-get"] + arguments)
        }
        #endif
        
        var packageOperations: [String: [[String: Any]]] = [:]
        var packageInstalls: [[String: String]] = []
        var packageRemovals: [[String: String]] = []
        var packageErrors: [[String: Any]] = []

        let aptLines = aptOutput.components(separatedBy: "\n")
        var fullJsonParseMode = false
        var fullJsonToParse = [String]()
        for aptLine in aptLines {
            if aptLine == "{" {
                fullJsonParseMode = true
                fullJsonToParse.append(aptLine)
            } else if fullJsonParseMode {
                // TODO: We can remove the workaround for the final line when Sam adds \n after the
                // JSON output. Currently it ends up like "}6 upgraded, 0 newly installed, …".
                if aptLine.hasPrefix("}") {
                    fullJsonToParse.append("}")
                    break
                } else {
                    fullJsonToParse.append(aptLine)
                }
            } else if aptLine.hasPrefix("{") && aptLine.hasSuffix("}") {
                guard let aptOp = try? JSONSerialization.jsonObject(with: aptLine.data(using: .utf8) ?? Data(),
                                                                    options: []) as? [String: String] else {
                    continue
                }
                if let type = aptOp["Type"],
                    let packageID = aptOp["Package"],
                    let version = aptOp["Version"] {
                    if type == "Inst"{
                        packageInstalls.append([
                            "package": packageID,
                            "version": version
                        ])
                    } else if type == "Remv" || type == "Purg" {
                        packageRemovals.append([
                            "package": packageID,
                            "version": version
                        ])
                    }
                }
            }
        }
        if fullJsonParseMode {
            let joined = fullJsonToParse.joined(separator: "\n")
            guard let json = try? JSONSerialization.jsonObject(with: joined.data(using: .utf8)!,
                                                               options: []) as? [String: Any] else {
                return [:]
            }
            if let operations = json["operations"] as? [[String: String]] {
                for aptOp in operations {
                    if let type = aptOp["Type"],
                        let packageID = aptOp["Package"],
                        let version = aptOp["CandidateVersion"] {
                        if type == "Inst"{
                            packageInstalls.append([
                                "package": packageID,
                                "version": version
                            ])
                        } else if type == "Remv" || type == "Purg" {
                            packageRemovals.append([
                                "package": packageID,
                                "version": version
                            ])
                        }
                    }
                }
            }
            if let dependencyOutput = json["brokenPackages"] as? [String: [[[String: String]]]] {
                for (packageID, dependencyCandidateLists) in dependencyOutput {
                    guard let package = PackageListManager.shared.newestPackage(identifier: packageID) else {
                        continue
                    }
                    for dependencyCandidateList in dependencyCandidateLists {
                        for dependency in dependencyCandidateList {
                            if let dependencyType = dependency["Type"],
                                let dependencyPackage = dependency["Package"] {
                                packageErrors.append([
                                    "package": package,
                                    "key": dependencyType,
                                    "otherPkg": dependencyPackage
                                ])
                            }
                        }
                    }
                }
            }
        }
        packageOperations["Inst"] = packageInstalls
        packageOperations["Remv"] = packageRemovals
        
        let aptErrorLines = aptOutput.components(separatedBy: "\n")
        
        var isDependencies = false
        
        for aptErrorLine in aptErrorLines {
            if !isDependencies {
                if aptErrorLine == "The following packages have unmet dependencies:" {
                    isDependencies = true
                    continue
                }
            } else {
                if aptErrorLine.hasPrefix("{") && aptErrorLine.hasSuffix("}") {
                    guard let dependencyOutput = try? JSONSerialization.jsonObject(with: aptErrorLine.data(using: .utf8) ?? Data(),
                                                                                   options: []) as? [String: [[[String: String]]]] else {
                        continue
                    }
                    for (packageID, dependencyCandidateLists) in dependencyOutput {
                        guard let package = PackageListManager.shared.newestPackage(identifier: packageID) else {
                            continue
                        }
                        for dependencyCandidateList in dependencyCandidateLists {
                            for dependency in dependencyCandidateList {
                                if let dependencyType = dependency["Type"],
                                    let dependencyPackage = dependency["Package"] {
                                    packageErrors.append([
                                        "package": package,
                                        "key": dependencyType,
                                        "otherPkg": dependencyPackage
                                    ])
                                }
                            }
                        }
                    }
                }
            }
        }
        
        packageOperations["Err"] = packageErrors
        return packageOperations
    }
    
    public class func installProgress(aptStatus: String) -> (Bool, Double, String) {
        let statusParts = aptStatus.components(separatedBy: ":")
        if statusParts.count < 4 {
            return (false, 0, "")
        }
        if statusParts[0] != "pmstatus" {
            return (false, 0, "")
        }
        
        //let packageName = statusParts[1]
        
        guard let rawProgress = Double(statusParts[2]) else {
            return (false, 0, "")
        }
        let statusReadable = statusParts[3]
        return (true, rawProgress, statusReadable)
    }
    
    public class func verifySignature(key: String, data: String, error: inout String) -> Bool {
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        error = "GnuPG not available in iOS Simulator"
        return false
        #endif
        
        let (_, output, _) = spawn(command: "/bin/sh", args: ["sh", "/usr/bin/apt-key", "verify", "-q", "--status-fd", "1", key, data])
        
        let outputLines = output.components(separatedBy: "\n")
        
        var keyIsGood = false
        var keyIsTrusted = false
        
        let substrCount = GNUPGPREFIX.count + 1
        
        for outputLine in outputLines {
            for prefix in [GNUPGBADSIG, GNUPGERRSIG, GNUPGEXPSIG, GNUPGREVKEYSIG, GNUPGNOPUBKEY, GNUPGNODATA] {
                if outputLine.hasPrefix(prefix) {
                    let index = outputLine.index(outputLine.startIndex, offsetBy: substrCount)
                    error = String(outputLine[index...])
                    keyIsGood = false
                }
            }
            if outputLine.hasPrefix(GNUPGGOODSIG) {
                keyIsGood = true
            }
            if outputLine.hasPrefix(GNUPGVALIDSIG) {
                let sigComponents = outputLine.components(separatedBy: " ")
                if sigComponents.count < 10 {
                    continue
                }
                
                //let sig = sigComponents[2]
                let digestType = sigComponents[9]
                
                guard let digestIdx = Int(digestType),
                    digestIdx <= digests.count else {
                        continue
                }
                
                let digest = digests[digestIdx]
                if digest.state == .trusted {
                    keyIsTrusted = true
                }
            }
        }
        return keyIsGood && keyIsTrusted
    }
    
    public class func performOperations(installs: [DownloadPackage],
                                        removals: [DownloadPackage],
                                        progressCallback: @escaping (Double, Bool, String) -> Void,
                                        outputCallback: @escaping (String, Int) -> Void,
                                        completionCallback: @escaping (Int, FINISH) -> Void) {
        guard let giveMeRootPath = Bundle.main.path(forAuxiliaryExecutable: "giveMeRoot") else {
            fatalError("Unable to find giveMeRoot")
        }
        
        #warning("TODO: remove --allow-unauthenticated")
        var arguments = ["apt-get", "install", "--reinstall", "--allow-unauthenticated",
                         "--allow-downgrades", "--no-download", "--allow-remove-essential",
                         "-c", Bundle.main.path(forResource: "sileo-apt", ofType: "conf") ?? "",
                         "-y", "-f", "-o", "APT::Status-Fd=5", "-o", "APT::Keep-Fds::=6",
                         "-o", "APT::Sandbox::User=root"]
        for package in installs {
            var packagesStr = package.package.package + "=" + package.package.version
            if package.package.package.contains("/") {
                packagesStr = package.package.package
            }
            packagesStr = "\"\(packagesStr)\""
            arguments.append(packagesStr)
        }
        for package in removals {
            var packageStr = package.package.package + "-"
            packageStr = "\"\(packageStr)\""
            arguments.append(packageStr)
        }
        
        let command = "CYDIA=\"6 1\" SILEO=\"6 1\" " + arguments.joined(separator: " ")
        
        DispatchQueue.global(qos: .default).async {
            var oldApps = APTWrapper.dictionaryOfScannedApps()
            
            var pipestatusfd: [Int32] = [0, 0]
            var pipestdout: [Int32] = [0, 0]
            var pipestderr: [Int32] = [0, 0]
            var pipesileo: [Int32] = [0, 0]
            
            var bufsiz = Int(BUFSIZ)
            
            pipe(&pipestdout)
            pipe(&pipestderr)
            pipe(&pipestatusfd)
            pipe(&pipesileo)
            
            guard fcntl(pipestdout[0], F_SETFL, O_NONBLOCK) != -1,
                fcntl(pipestderr[0], F_SETFL, O_NONBLOCK) != -1,
                fcntl(pipestatusfd[0], F_SETFL, O_NONBLOCK) != -1,
                fcntl(pipesileo[0], F_SETFL, O_NONBLOCK) != -1 else {
                    fatalError("Unable to set attributes on pipe")
            }
            
            var fileActions: posix_spawn_file_actions_t?
            posix_spawn_file_actions_init(&fileActions)
            posix_spawn_file_actions_addclose(&fileActions, pipestdout[0])
            posix_spawn_file_actions_addclose(&fileActions, pipestderr[0])
            posix_spawn_file_actions_addclose(&fileActions, pipestatusfd[0])
            posix_spawn_file_actions_addclose(&fileActions, pipesileo[0])
            posix_spawn_file_actions_adddup2(&fileActions, pipestdout[1], STDOUT_FILENO)
            posix_spawn_file_actions_adddup2(&fileActions, pipestderr[1], STDERR_FILENO)
            posix_spawn_file_actions_adddup2(&fileActions, pipestatusfd[1], 5)
            posix_spawn_file_actions_adddup2(&fileActions, pipesileo[1], Int32(sileoFD))
            posix_spawn_file_actions_addclose(&fileActions, pipestdout[1])
            posix_spawn_file_actions_addclose(&fileActions, pipestderr[1])
            posix_spawn_file_actions_addclose(&fileActions, pipestatusfd[1])
            posix_spawn_file_actions_addclose(&fileActions, pipesileo[1])
            
            let args = ["giveMeRoot", command]
            
            let argv: [UnsafeMutablePointer<CChar>?] = args.map { $0.withCString(strdup) }
            defer { for case let arg? in argv { free(arg) } }
            
            var pid: pid_t = 0
            
            let retVal = posix_spawn(&pid, giveMeRootPath, &fileActions, nil, argv + [nil], environ)
            if retVal < 0 {
                return
            }
            
            close(pipestdout[1])
            close(pipestderr[1])
            close(pipestatusfd[1])
            close(pipesileo[1])
            
            var finish = FINISH.back
            var runUICache = false
            
            let mutex = DispatchSemaphore(value: 0)
            
            let readQueue = DispatchQueue(label: "org.coolstar.sileo.command",
                                          qos: .userInitiated,
                                          attributes: .concurrent,
                                          autoreleaseFrequency: .inherit,
                                          target: nil)
            
            let stdoutSource = DispatchSource.makeReadSource(fileDescriptor: pipestdout[0], queue: readQueue)
            let stderrSource = DispatchSource.makeReadSource(fileDescriptor: pipestderr[0], queue: readQueue)
            let statusFdSource = DispatchSource.makeReadSource(fileDescriptor: pipestatusfd[0], queue: readQueue)
            let sileoFdSource = DispatchSource.makeReadSource(fileDescriptor: pipesileo[0], queue: readQueue)
            
            stdoutSource.setCancelHandler {
                close(pipestdout[0])
                mutex.signal()
            }
            stderrSource.setCancelHandler {
                close(pipestderr[0])
                mutex.signal()
            }
            statusFdSource.setCancelHandler {
                close(pipestatusfd[0])
                mutex.signal()
            }
            sileoFdSource.setCancelHandler {
                close(pipesileo[0])
            }
            
            stdoutSource.setEventHandler {
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufsiz)
                defer { buffer.deallocate() }
                
                let bytesRead = read(pipestdout[0], buffer, bufsiz)
                guard bytesRead > 0 else {
                    if bytesRead == -1 && errno == EAGAIN {
                        return
                    }
                    
                    stdoutSource.cancel()
                    return
                }
                
                let array = Array(UnsafeBufferPointer(start: buffer, count: bytesRead)) + [UInt8(0)]
                array.withUnsafeBufferPointer { ptr in
                    let str = String(cString: unsafeBitCast(ptr.baseAddress, to: UnsafePointer<CChar>.self))
                    outputCallback(str, Int(STDOUT_FILENO))
                }
            }
            stderrSource.setEventHandler {
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufsiz)
                defer { buffer.deallocate() }
                
                let bytesRead = read(pipestderr[0], buffer, bufsiz)
                guard bytesRead > 0 else {
                    if bytesRead == -1 && errno == EAGAIN {
                        return
                    }
                    
                    stderrSource.cancel()
                    return
                }
                
                let array = Array(UnsafeBufferPointer(start: buffer, count: bytesRead)) + [UInt8(0)]
                array.withUnsafeBufferPointer { ptr in
                    let str = String(cString: unsafeBitCast(ptr.baseAddress, to: UnsafePointer<CChar>.self))
                    outputCallback(str, Int(STDERR_FILENO))
                }
            }
            statusFdSource.setEventHandler {
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufsiz)
                defer { buffer.deallocate() }
                
                let bytesRead = read(pipestatusfd[0], buffer, bufsiz)
                guard bytesRead > 0 else {
                    if bytesRead == -1 && errno == EAGAIN {
                        return
                    }
                    
                    statusFdSource.cancel()
                    return
                }
                
                let array = Array(UnsafeBufferPointer(start: buffer, count: bytesRead)) + [UInt8(0)]
                array.withUnsafeBufferPointer { ptr in
                    let str = String(cString: unsafeBitCast(ptr.baseAddress, to: UnsafePointer<CChar>.self))
                    
                    let statusLines = str.components(separatedBy: "\n")
                    for status in statusLines {
                        let (statusValid, statusProgress, statusReadable) = self.installProgress(aptStatus: status)
                        progressCallback(statusProgress, statusValid, statusReadable)
                    }
                }
            }
            sileoFdSource.setEventHandler {
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufsiz)
                defer { buffer.deallocate() }
                
                let bytesRead = read(pipesileo[0], buffer, bufsiz)
                guard bytesRead > 0 else {
                    if bytesRead == -1 && errno == EAGAIN {
                        return
                    }
                    
                    statusFdSource.cancel()
                    return
                }
                
                let array = Array(UnsafeBufferPointer(start: buffer, count: bytesRead)) + [UInt8(0)]
                array.withUnsafeBufferPointer { ptr in
                    let str = String(cString: unsafeBitCast(ptr.baseAddress, to: UnsafePointer<CChar>.self))
                    
                    let sileoLines = str.components(separatedBy: "\n")
                    for sileoLine in sileoLines {
                        if sileoLine.hasPrefix("finish:") {
                            var newFinish = FINISH.back
                            if sileoLine.hasPrefix("finish:return") {
                                newFinish = .back
                            }
                            if sileoLine.hasPrefix("finish:uicache") {
                                newFinish = .uicache
                                runUICache = true
                            }
                            if sileoLine.hasPrefix("finish:reopen") {
                                newFinish = .reopen
                            }
                            if sileoLine.hasPrefix("finish:restart") {
                                newFinish = .restart
                            }
                            if sileoLine.hasPrefix("finish:reload") {
                                newFinish = .reload
                            }
                            if sileoLine.hasPrefix("finish:reboot") {
                                newFinish = .reboot
                            }
                            
                            if newFinish.rawValue > finish.rawValue {
                                finish = newFinish
                            }
                        }
                    }
                }
            }
            
            stdoutSource.resume()
            stderrSource.resume()
            statusFdSource.resume()
            sileoFdSource.resume()
            
            mutex.wait()
            mutex.wait()
            mutex.wait()
            
            if !sileoFdSource.isCancelled {
                sileoFdSource.cancel()
            }
            
            var status: Int32 = 0
            waitpid(pid, &status, 0)
            
            if runUICache {
                progressCallback(99, true, "Updating icon cache...")
                outputCallback("Updating Icon Cache\n", debugFD)
                
                var newApps = dictionaryOfScannedApps()
                
                for key in oldApps.keys where oldApps[key] == newApps[key] {
                    oldApps.removeValue(forKey: key)
                    newApps.removeValue(forKey: key)
                }
                
                for key in newApps.keys where oldApps[key] == newApps[key] {
                    oldApps.removeValue(forKey: key)
                    newApps.removeValue(forKey: key)
                }
                
                let diff = newApps.merging(oldApps) { current, _ in current }
                
                for appName in diff.keys {
                    let appPath = URL(fileURLWithPath: "/Applications/").appendingPathComponent(appName)
                    
                    spawn(command: "/usr/bin/uicache", args: ["uicache", "-p", appPath.path])
                }
            }
            
            spawnAsRoot(command: "/usr/bin/apt-get clean")
            
            completionCallback(Int(status), finish)
        }
    }
}
