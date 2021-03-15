import Foundation

@discardableResult func spawn(command: String, args: [String]) -> (Int, String, String) {
    var pipestdout: [Int32] = [0, 0]
    var pipestderr: [Int32] = [0, 0]
    
    let bufsiz = Int(BUFSIZ)
    
    pipe(&pipestdout)
    pipe(&pipestderr)
    
    guard fcntl(pipestdout[0], F_SETFL, O_NONBLOCK) != -1 else {
        return (-1, "", "")
    }
    guard fcntl(pipestderr[0], F_SETFL, O_NONBLOCK) != -1 else {
        return (-1, "", "")
    }
    
    var fileActions: posix_spawn_file_actions_t?
    posix_spawn_file_actions_init(&fileActions)
    posix_spawn_file_actions_addclose(&fileActions, pipestdout[0])
    posix_spawn_file_actions_addclose(&fileActions, pipestderr[0])
    posix_spawn_file_actions_adddup2(&fileActions, pipestdout[1], STDOUT_FILENO)
    posix_spawn_file_actions_adddup2(&fileActions, pipestderr[1], STDERR_FILENO)
    posix_spawn_file_actions_addclose(&fileActions, pipestdout[1])
    posix_spawn_file_actions_addclose(&fileActions, pipestderr[1])
    
    let argv: [UnsafeMutablePointer<CChar>?] = args.map { $0.withCString(strdup) }
    defer { for case let arg? in argv { free(arg) } }
    
    var pid: pid_t = 0
    
    let retVal = posix_spawn(&pid, command, &fileActions, nil, argv + [nil], environ)
    if retVal < 0 {
        return (-1, "", "")
    }
    
    close(pipestdout[1])
    close(pipestderr[1])
    
    var stdoutStr = ""
    var stderrStr = ""
    
    let mutex = DispatchSemaphore(value: 0)
    
    let readQueue = DispatchQueue(label: "org.coolstar.sileo.command",
                                  qos: .userInitiated,
                                  attributes: .concurrent,
                                  autoreleaseFrequency: .inherit,
                                  target: nil)
    
    let stdoutSource = DispatchSource.makeReadSource(fileDescriptor: pipestdout[0], queue: readQueue)
    let stderrSource = DispatchSource.makeReadSource(fileDescriptor: pipestderr[0], queue: readQueue)
    
    stdoutSource.setCancelHandler {
        close(pipestdout[0])
        mutex.signal()
    }
    stderrSource.setCancelHandler {
        close(pipestderr[0])
        mutex.signal()
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
            stdoutStr += str
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
            stderrStr += str
        }
    }
    
    stdoutSource.resume()
    stderrSource.resume()
    
    mutex.wait()
    mutex.wait()
    var status: Int32 = 0
    waitpid(pid, &status, 0)
    return (Int(status), stdoutStr, stderrStr)
}

@discardableResult func spawnAsRoot(command: String) -> (Int, String, String) {
    guard let giveMeRootPath = Bundle.main.path(forAuxiliaryExecutable: "giveMeRoot") else {
        return (-1, "", "")
    }
    return spawn(command: giveMeRootPath, args: ["giveMeRoot", command])
}

func deleteFileAsRoot(_ url: URL) {
    #if targetEnvironment(simulator) || TARGET_SANDBOX
    try? FileManager.default.removeItem(at: url)
    #else
    spawnAsRoot(command: "rm '\(url.path)' || true")
    #endif
}

func copyFileAsRoot(from: URL, to: URL) {
    deleteFileAsRoot(to)

    #if targetEnvironment(simulator) || TARGET_SANDBOX
    try? FileManager.default.copyItem(at: from, to: to)
    #else
    spawnAsRoot(command: "cp '\(from.path)' '\(to.path)' ; chown 0:0 '\(to.path)' ; chmod 0644 '\(to.path)'")
    #endif
}

func cloneFileAsRoot(from: URL, to: URL) {
    deleteFileAsRoot(to)

    #if targetEnvironment(simulator) || TARGET_SANDBOX
    try? FileManager.default.copyItem(at: from, to: to)
    #else
    if FileManager.default.fileExists(atPath: "/usr/bin/bsdcp") {
        spawnAsRoot(command: "bsdcp -c '\(from.path)' '\(to.path)' ; chown 0:0 '\(to.path)' ; chmod 0644 '\(to.path)'")
    } else {
        spawnAsRoot(command: "cp -c '\(from.path)' '\(to.path)' ; chown 0:0 '\(to.path)' ; chmod 0644 '\(to.path)'")
    }
    #endif
}

func moveFileAsRoot(from: URL, to: URL) {
    deleteFileAsRoot(to)
    
    #if targetEnvironment(simulator) || TARGET_SANDBOX
    try? FileManager.default.moveItem(at: from, to: to)
    #else
    spawnAsRoot(command: "mv '\(from.path)' '\(to.path)' ; chown 0:0 '\(to.path)' ; chmod 0644 '\(to.path)'")
    #endif
}
