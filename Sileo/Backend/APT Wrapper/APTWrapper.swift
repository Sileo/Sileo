//
//  APTWrapper.swift
//  Sileo
//
//  Created by CoolStar on 8/24/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
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

        guard let apps = try? fileManager.contentsOfDirectory(atPath: "\(CommandPath.prefix)/Applications") else {
            return dictionary
        }

        for app in apps {
            let infoPlist = String(format: "\(CommandPath.prefix)/Applications/%@/Info.plist", app)

            guard let attr = try? fileManager.attributesOfItem(atPath: infoPlist) else {
                continue
            }

            let fileNumber = attr[FileAttributeKey.systemFileNumber] as? Int64
            dictionary[app] = fileNumber
        }
        return dictionary
    }

    public class func installProgress(aptStatus: String) -> (Bool, Double, String, String) {
        let statusParts = aptStatus.components(separatedBy: ":")
        if statusParts.count < 4 {
            return (false, 0, "", "")
        }
        if statusParts[0] != "pmstatus" {
            return (false, 0, "", "")
        }

        let packageName = statusParts[1]
        guard let rawProgress = Double(statusParts[2]) else {
            return (false, 0, "", "")
        }
        let statusReadable = statusParts[3]
        return (true, rawProgress, statusReadable, packageName)
    }

    public class func verifySignature(key: String, data: String, error: inout String) -> Bool {
        #if targetEnvironment(simulator) || TARGET_SANDBOX

        error = "GnuPG not available in sandboxed environment"
        return false

        #else

        let (_, output, _) = spawn(command: CommandPath.sh, args: ["sh", CommandPath.aptkey, "verify", "-q", "--status-fd", "1", key, data])

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

                // let sig = sigComponents[2]
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

        #endif
    }

    public class func performOperations(installs: [DownloadPackage],
                                        removals: [DownloadPackage],
                                        installDeps: [DownloadPackage],
                                        progressCallback: @escaping (Double, Bool, String, String) -> Void,
                                        outputCallback: @escaping (String, Int) -> Void,
                                        completionCallback: @escaping (Int, FINISH, Bool) -> Void) {
        var arguments = [CommandPath.aptget, "install", "--reinstall", "--allow-unauthenticated", "--allow-downgrades",
                        "--no-download", "--allow-remove-essential", "--allow-change-held-packages",
                         "-c", Bundle.main.path(forResource: "sileo-apt", ofType: "conf") ?? "",
                         "-y", "-f", "-o", "APT::Status-Fd=5", "-o", "APT::Keep-Fds::=6",
                         "-o", "Acquire::AllowUnsizedPackages=true", "-o", "APT::Sandbox::User=root", "-o", "Dpkg::Options::=--force-confdef", "-o", "Dpkg::Options::=--force-confnew"]
        for package in installs {
            var packagesStr = package.package.package + "=" + package.package.version
            if package.package.package.contains("/") {
                packagesStr = package.package.package
            }
            arguments.append(packagesStr)
        }
        for package in removals {
            let packageStr = package.package.package + "-"
            arguments.append(packageStr)
        }
        var finish = FINISH.back
        #if targetEnvironment(macCatalyst)
        arguments[0] = "apt-get"
        DispatchQueue.global(qos: .default).async {
            let wrapper = MacRootWrapper.shared
            let pipeObject = wrapper.sharedPipe
            pipeObject.stdoutCompletion = { str in
                outputCallback(str, Int(STDOUT_FILENO))
            }
            pipeObject.stderrCompletion = { str in
                outputCallback(str, Int(STDERR_FILENO))
            }
            pipeObject.statusFdCompletion = { str in
                let statusLines = str.components(separatedBy: "\n")
                for status in statusLines {
                    let (statusValid, statusProgress, statusReadable, package) = self.installProgress(aptStatus: status)
                    progressCallback(statusProgress, statusValid, statusReadable, package)
                }
            }
            pipeObject.pipeCompletion = { status in
                wrapper.resetConnection()
                spawnAsRoot(args: [CommandPath.aptget, "clean"])
                for file in DownloadManager.shared.cachedFiles {
                    deleteFileAsRoot(file)
                }
                completionCallback(Int(status), finish, false)
            }
            guard let helper = MacRootWrapper.shared.helper else {
                fatalError("[Sileo] Protocol 3: Protect the Pilot")
            }
            helper.spawnAsRoot(command: CommandPath.aptget, args: arguments)
        }
        #else
        guard let giveMeRootPath = Bundle.main.path(forAuxiliaryExecutable: "giveMeRoot") else {
            fatalError("Unable to find giveMeRoot")
        }
        DispatchQueue.global(qos: .default).async {
            let oldApps = APTWrapper.dictionaryOfScannedApps()

            var pipestatusfd: [Int32] = [0, 0]
            var pipestdout: [Int32] = [0, 0]
            var pipestderr: [Int32] = [0, 0]
            var pipesileo: [Int32] = [0, 0]

            let bufsiz = Int(BUFSIZ)

            pipe(&pipestdout)
            pipe(&pipestderr)
            pipe(&pipestatusfd)
            pipe(&pipesileo)

            guard fcntl(pipestdout[0], F_SETFL, O_NONBLOCK) != -1,
                  fcntl(pipestderr[0], F_SETFL, O_NONBLOCK) != -1,
                  fcntl(pipestatusfd[0], F_SETFL, O_NONBLOCK) != -1,
                  fcntl(pipesileo[0], F_SETFL, O_NONBLOCK) != -1
            else {
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

            arguments.insert("giveMeRoot", at: 0)

            let argv: [UnsafeMutablePointer<CChar>?] = arguments.map { $0.withCString(strdup) }
            defer {
                for case let arg? in argv {
                    free(arg)
                }
            }

            let environment = ["SILEO=6 1", "CYDIA=6 1"]
            let env: [UnsafeMutablePointer<CChar>?] = environment.map { $0.withCString(strdup) }
            defer {
                for case let key? in env {
                    free(key)
                }
            }

            var pid: pid_t = 0
            
            let spawnStatus = posix_spawn(&pid, giveMeRootPath, &fileActions, nil, argv + [nil], env + [nil])
            if spawnStatus != 0 {
                return
            }

            close(pipestdout[1])
            close(pipestderr[1])
            close(pipestatusfd[1])
            close(pipesileo[1])

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
                        let (statusValid, statusProgress, statusReadable, package) = self.installProgress(aptStatus: status)
                        progressCallback(statusProgress, statusValid, statusReadable, package)
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
            var refreshSileo = false
            
            let newApps = dictionaryOfScannedApps()
            var difference = Set<String>()
            for (key, _) in oldApps where newApps[key] == nil {
                difference.insert(key)
            }
            for (key, _) in newApps where oldApps[key] == nil {
                difference.insert(key)
            }
            for (key, value) in newApps where oldApps[key] != nil {
                guard let oldValue = oldApps[key] else { continue }
                if oldValue != value {
                    difference.insert(key)
                }
            }
            if !difference.isEmpty {
                outputCallback("Updating Icon Cache\n", debugFD)
                for appName in difference {
                    let appPath = URL(fileURLWithPath: "\(CommandPath.prefix)/Applications/").appendingPathComponent(appName)
                    if appPath.path == Bundle.main.bundlePath {
                        refreshSileo = true
                    } else {
                        spawn(command: "\(CommandPath.prefix)/usr/bin/uicache", args: ["uicache", "-p", "\(appPath.path)"])
                    }
                }
            }

            spawnAsRoot(args: [CommandPath.aptget, "clean"])
            for file in DownloadManager.shared.cachedFiles {
                deleteFileAsRoot(file)
            }
            completionCallback(Int(status), finish, refreshSileo)
        }
        #endif
    }
}
