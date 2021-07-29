//
//  Listener.swift
//  SileoRootDaemon
//
//  Created by Andromeda on 12/07/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

import Foundation

public class RootHelper: NSObject, NSXPCListenerDelegate, RootHelperProtocol, AptRootPipeProtocol {
    
    static let sileoFD = 6
    static let cydiaCompatFd = 6
    static let debugFD = 11
    
    var listener: NSXPCListener
    var connection: NSXPCConnection?
    
    override init() {
        listener = NSXPCListener(machServiceName: "SileoRootDaemon")
        super.init()
        listener.delegate = self
        
        listener.resume()
        RunLoop.current.run()
    }
    
    public func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Check the connection is being made from software signed with the same certificate
        guard self.isValid(connection: newConnection) else {
            return false
        }
        newConnection.exportedInterface = NSXPCInterface(with: RootHelperProtocol.self)
        newConnection.remoteObjectInterface = NSXPCInterface(with: AptRootPipeProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        self.connection = newConnection
        return true
    }
    
    public func spawn(command: String, args: [String], _ completion: @escaping (Int, String, String) -> Void) {
        NSLog("[Sileo] Spawn Command has been made for \(command)")
        var pipestdout: [Int32] = [0, 0]
        var pipestderr: [Int32] = [0, 0]
        
        let bufsiz = Int(BUFSIZ)
        
        pipe(&pipestdout)
        pipe(&pipestderr)
        
        guard fcntl(pipestdout[0], F_SETFL, O_NONBLOCK) != -1 else {
            return completion(-1, "", "")
        }
        guard fcntl(pipestderr[0], F_SETFL, O_NONBLOCK) != -1 else {
            return completion(-1, "", "")
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
        
        let env = [ "PATH=/opt/procursus/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin" ]
        let proenv: [UnsafeMutablePointer<CChar>?] = env.map { $0.withCString(strdup) }
        defer { for case let pro? in proenv { free(pro) } }
        NSLog("[Sileo] getting spawn status of \(command)")
        let spawnStatus = posix_spawn(&pid, command, &fileActions, nil, argv + [nil], proenv + [nil])
        NSLog("[Sileo] spawn status of \(command) = \(spawnStatus)")
        if spawnStatus != 0 {
            return completion(-1, "", "")
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
        NSLog("[Sileo] waiting for pid of \(command)")
        waitpid(pid, &status, 0)
        NSLog("[Sileo] Got status and calling completion")
        completion(Int(status), stdoutStr, stderrStr)
        NSLog("[Sileo] Fired completion")
    }
    
    public func version(_ completion: @escaping (String) -> Void) {
        completion(DaemonVersion)
    }
    
    public func spawnAsRoot(command: String, args: [String]) {
        guard let connection = connection,
              let helper = connection.remoteObjectProxyWithErrorHandler({ error in
            NSLog("[Sileo] Error = \(error)")
            return
        }) as? AptRootPipeProtocol else {
            NSLog("[Sileo] Daemon not installed")
            return
        }
        var pipestatusfd: [Int32] = [0, 0]
        var pipestdout: [Int32] = [0, 0]
        var pipestderr: [Int32] = [0, 0]

        let bufsiz = Int(BUFSIZ)

        pipe(&pipestdout)
        pipe(&pipestderr)
        pipe(&pipestatusfd)

        guard fcntl(pipestdout[0], F_SETFL, O_NONBLOCK) != -1,
              fcntl(pipestderr[0], F_SETFL, O_NONBLOCK) != -1,
              fcntl(pipestatusfd[0], F_SETFL, O_NONBLOCK) != -1
        else {
            fatalError("Unable to set attributes on pipe")
        }
        
        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        posix_spawn_file_actions_addclose(&fileActions, pipestdout[0])
        posix_spawn_file_actions_addclose(&fileActions, pipestderr[0])
        posix_spawn_file_actions_addclose(&fileActions, pipestatusfd[0])
        posix_spawn_file_actions_adddup2(&fileActions, pipestdout[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, pipestderr[1], STDERR_FILENO)
        posix_spawn_file_actions_adddup2(&fileActions, pipestatusfd[1], 5)
        posix_spawn_file_actions_addclose(&fileActions, pipestdout[1])
        posix_spawn_file_actions_addclose(&fileActions, pipestderr[1])
        posix_spawn_file_actions_addclose(&fileActions, pipestatusfd[1])

        let argv: [UnsafeMutablePointer<CChar>?] = args.map { $0.withCString(strdup) }
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
        
        NSLog("[Sileo] Firing posix_spawn")
        var pid: pid_t = 0
        let spawnStatus = posix_spawn(&pid, command, &fileActions, nil, argv + [nil], env + [nil])
        if spawnStatus != 0 {
            NSLog("[Sileo] Exiting early with spawnStatus \(spawnStatus)")
            helper.completion?(status: -1)
            return
        }

        close(pipestdout[1])
        close(pipestderr[1])
        close(pipestatusfd[1])

        let mutex = DispatchSemaphore(value: 0)

        let readQueue = DispatchQueue(label: "org.coolstar.sileo.command",
                                      qos: .userInitiated,
                                      attributes: .concurrent,
                                      autoreleaseFrequency: .inherit,
                                      target: nil)
        
        NSLog("[Sileo] Setting up read sources")
        let stdoutSource = DispatchSource.makeReadSource(fileDescriptor: pipestdout[0], queue: readQueue)
        let stderrSource = DispatchSource.makeReadSource(fileDescriptor: pipestderr[0], queue: readQueue)
        let statusFdSource = DispatchSource.makeReadSource(fileDescriptor: pipestatusfd[0], queue: readQueue)

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
                NSLog("[Sileo] stdout pipe \(str)")
                helper.stdout?(str: str)
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
                NSLog("[Sileo] stderr pipe \(str)")
                helper.stderr?(str: str)
            }
        }
        statusFdSource.setEventHandler {
            NSLog("[Sileo] statusFdSource event")
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
                
                NSLog("[Sileo] statusfd pipe \(str)")
                helper.statusFd?(str: str)
            }
        }

        stdoutSource.resume()
        stderrSource.resume()
        statusFdSource.resume()

        mutex.wait()
        mutex.wait()
        mutex.wait()

        NSLog("[Sileo] Waiting for PID")
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        NSLog("[Sileo] Finished Waiting for PID")
        helper.completion?(status: Int(status))
    }
    
    private func isValid(connection: NSXPCConnection) -> Bool {
        do {
            return try CodesignCheck.codeSigningMatches(pid: connection.processIdentifier)
        } catch {
            NSLog("Code signing check failed with error: \(error)")
            return false
        }
    }
    
}
