import Foundation
import Darwin

#if targetEnvironment(macCatalyst)
final public class MacRootWrapper {

    static let shared = MacRootWrapper()
    let sharedPipe = AptRootPipeWrapper()

    public var connection: NSXPCConnection?
    private var invalidated = false
    public var helper: RootHelperProtocol?
    public var wrapperClass: LaunchAsRoot.Type

    init() {
        guard let bundleURL = Bundle.main.builtInPlugInsURL?.appendingPathComponent("SileoRootWrapper.bundle"),
              let bundle = Bundle(url: bundleURL),
              bundle.load(),
              let klass = objc_getClass("LaunchAsRoot") as? LaunchAsRoot.Type
        else {
            fatalError("Unable to initialize ability to spawn a process as root")
        }

        self.wrapperClass = klass
        _ = klass.shared
        func connect() {
            if !connectToDaemon() {
                klass.shared.installDaemon()
                guard connectToDaemon() else {
                    fatalError("[Sileo] Authorization Alpha-Alpha 3-0-5.")
                }
            }
        }
        connect()

        guard let helper = helper else { fatalError("[Sileo] Protocol 3: Protect the Pilot") }
        helper.version { version in
            guard version == DaemonVersion else {
                self.connection?.invalidationHandler = nil
                self.connection?.invalidate()

                klass.shared.installDaemon()
                guard self.connectToDaemon() else {
                    fatalError("[Sileo] Authorization Alpha-Alpha 3-0-5.")
                }
                return
            }
        }
    }

    public func spawn(args: [String], outputCallback: ((_ output: String?) -> Void)? = nil) -> (Int, String, String) {
        guard !args.isEmpty,
              let launchPath = args.first
        else {
            fatalError("Found invalid args when spawning a process as root")
        }

        var arguments = args
        arguments.removeFirst()

        var status = -1
        var stdoutStr = ""
        var stderrStr = ""

        guard let helper = helper else {
            fatalError("[Sileo] Protocol 3: Protect the Pilot")
        }
        // swiftlint:disable identifier_name
        helper.spawn(command: launchPath, args: args) { _status, _stdoutStr, _stderrStr in
            status = _status
            stdoutStr = _stdoutStr
            stderrStr = _stderrStr
        }
        return (status, stdoutStr, stderrStr)
    }

    public func connectToDaemon() -> Bool {
        guard self.connection == nil,
              let connection = wrapperClass.shared.connection(),
              self.helper == nil else { return true }
        connection.remoteObjectInterface = NSXPCInterface(with: RootHelperProtocol.self)
        connection.exportedInterface = NSXPCInterface(with: AptRootPipeProtocol.self)
        connection.exportedObject = sharedPipe
        connection.invalidationHandler = {
            self.invalidated = true
        }

        connection.resume()

        guard let helper = connection.synchronousRemoteObjectProxyWithErrorHandler({ _ in
            return
        }) as? RootHelperProtocol else {
            return false
        }
        var version = ""
        helper.version { _version in
            version = _version
        }
        guard version == DaemonVersion else {
            return false
        }
        self.connection = connection
        self.helper = helper
        return true
    }
    
    public func resetConnection() {
        self.connection?.invalidate()
        self.connection = nil
        self.helper = nil
        
        guard connectToDaemon() else {
            fatalError("[Sileo] Authorization Alpha-Alpha 3-0-5.")
        }
    }
}
#endif

@discardableResult func spawn(command: String, args: [String], root: Bool = false) -> (Int, String, String) {
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

    #if targetEnvironment(macCatalyst)
    let env = [ "PATH=/opt/procursus/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin" ]
    let proenv: [UnsafeMutablePointer<CChar>?] = env.map { $0.withCString(strdup) }
    defer { for case let pro? in proenv { free(pro) } }
    let spawnStatus = posix_spawn(&pid, command, &fileActions, nil, argv + [nil], proenv + [nil])
    #else
    // Weird problem with a weird workaround
    let env = [ "PATH=\(CommandPath.prefix)/usr/bin:\(CommandPath.prefix)/usr/local/bin:\(CommandPath.prefix)/bin:\(CommandPath.prefix)/usr/sbin" ]
    let envp: [UnsafeMutablePointer<CChar>?] = env.map { $0.withCString(strdup) }
    defer { for case let env? in envp { free(env) } }
    let spawnStatus: Int32
    if #available(iOS 13, *) {
        var attr: posix_spawnattr_t?
        if root {
            posix_spawnattr_init(&attr)
            posix_spawnattr_set_persona_np(&attr, 99, UInt32(POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE));
            posix_spawnattr_set_persona_uid_np(&attr, 0);
            posix_spawnattr_set_persona_gid_np(&attr, 0);
        }
        spawnStatus = posix_spawn(&pid, command, &fileActions, &attr, argv + [nil], envp + [nil])
    } else {
        spawnStatus = posix_spawn(&pid, command, &fileActions, nil, argv + [nil], envp)
    }
    #endif
    if spawnStatus != 0 {
        return (Int(spawnStatus), "ITS FAILING HERE", "Error = \(errno)  \(String(cString: strerror(spawnStatus))) \(String(cString: strerror(errno)))\n\(command)")
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

@discardableResult func spawnAsRoot(args: [String], platformatise: Bool = false, outputCallback: ((_ output: String?) -> Void)? = nil) -> (Int, String, String) {
    #if targetEnvironment(simulator) || TARGET_SANDBOX
    fatalError("Commands should not be run in sandbox")
    #elseif targetEnvironment(macCatalyst)
    MacRootWrapper.shared.spawn(args: args, outputCallback: outputCallback)
    #else
    if #available(iOS 13, *) {
        var args = args
        let command = args.first!
        args[0] = String(command.split(separator: "/").last!)
        return spawn(command:command, args: args, root: true)
    } else {
        guard let giveMeRootPath = Bundle.main.path(forAuxiliaryExecutable: "giveMeRoot") else {
            return (-1, "", "")
        }
        return spawn(command: giveMeRootPath, args: ["giveMeRoot"] + args)
    }
    #endif
}

func deleteFileAsRoot(_ url: URL) {
    #if targetEnvironment(simulator) || TARGET_SANDBOX
    try? FileManager.default.removeItem(at: url)
    #else
    spawnAsRoot(args: [CommandPath.rm, "-f", "\(url.path)"])
    #endif
}

func hardLinkAsRoot(from: URL, to: URL) {
    deleteFileAsRoot(to)

    #if targetEnvironment(simulator) || TARGET_SANDBOX
    try? FileManager.default.createSymbolicLink(at: to, withDestinationURL: from)
    #else
    spawnAsRoot(args: [CommandPath.ln, "\(from.path)", "\(to.path)"])
    spawnAsRoot(args: [CommandPath.chown, "0:0", "\(to.path)"])
    spawnAsRoot(args: [CommandPath.chmod, "0644", "\(to.path)"])
    #endif
}

func moveFileAsRoot(from: URL, to: URL) {
    deleteFileAsRoot(to)

    #if targetEnvironment(simulator) || TARGET_SANDBOX
    try? FileManager.default.moveItem(at: from, to: to)
    #else
    spawnAsRoot(args: [CommandPath.mv, "\(from.path)", "\(to.path)"])
    spawnAsRoot(args: [CommandPath.chown, "0:0", "\(to.path)"])
    spawnAsRoot(args: [CommandPath.chmod, "0644", "\(to.path)"])
    #endif
}

public class CommandPath {
    // Certain paths need to check for either Procursus mobile or Elucubratus as a fallback option
    // Every method that uses this check already accounts for macCatalyst paths still resolving too
    #if targetEnvironment(simulator) || TARGET_SANDBOX
    public static let isMobileProcursus = true
    #elseif targetEnvironment(macCatalyst)
    public static let isMobileProcursus = false
    #else
    public static let isMobileProcursus = FileManager.default.fileExists(atPath: "\(prefix)/.procursus_strapped")
    #endif
    
    static let prefix: String = {
        #if targetEnvironment(macCatalyst)
        return "/opt/procursus"
        #else
        if #available(iOS 15, *) {
            if URL(fileURLWithPath: "/var/Liy").dirExists {
                return "/var/Liy"
            }
            if URL(fileURLWithPath: "/var/jb").dirExists {
                return "/var/jb"
            }
        }
        return ""
        #endif
    }()

    // swiftlint:disable identifier_name
    static var mv: String = {
        if isMobileProcursus {
            return "\(prefix)/usr/bin/mv"
        }

        return "/bin/mv"
    }()

    static var chmod: String = {
        if isMobileProcursus {
            return "\(prefix)/usr/bin/chmod"
        }

        return "/bin/chmod"
    }()

    // swiftlint:disable identifier_name
    static var ln: String = {
        if isMobileProcursus {
            return "\(prefix)/usr/bin/ln"
        }

        return "/bin/ln"
    }()

    // swiftlint:disable identifier_name
    static var rm: String = {
        if isMobileProcursus {
            return "\(prefix)/usr/bin/rm"
        }

        return "/bin/rm"
    }()

    static var mkdir: String = {
        if isMobileProcursus {
            return "\(prefix)/usr/bin/mkdir"
        }

        return "/bin/mkdir"
    }()

    // swiftlint:disable identifier_name
    static var cp: String = {
        if isMobileProcursus {
            return "\(prefix)/usr/bin/cp"
        }

        return "/bin/cp"
    }()

    static var sourcesListD: String = {
        if requiresDumbWorkaround {
            return "/var/Liy/etc/apt/sources.list.d"
        }
        return "\(prefix)/etc/apt/sources.list.d"
    }()

    static var chown: String = {
        #if targetEnvironment(macCatalyst)
        return "/usr/sbin/chown"
        #else
        return "\(prefix)/usr/bin/chown"
        #endif
    }()

    static var aptmark: String = {
        #if targetEnvironment(macCatalyst)
        return "\(prefix)/bin/apt-mark"
        #else
        return "\(prefix)/usr/bin/apt-mark"
        #endif
    }()

    static var dpkgdeb: String = {
        #if targetEnvironment(macCatalyst)
        return "\(prefix)/bin/dpkg-deb"
        #else
        return "\(prefix)/usr/bin/dpkg-deb"
        #endif
    }()

    static var dpkg: String = {
        #if targetEnvironment(macCatalyst)
        return "\(prefix)/bin/dpkg"
        #else
        return "\(prefix)/usr/bin/dpkg"
        #endif
    }()

    static var aptget: String = {
        #if targetEnvironment(macCatalyst)
        return "\(prefix)/bin/apt-get"
        #else
        return "\(prefix)/usr/bin/apt-get"
        #endif
    }()

    static var aptkey: String = {
        #if targetEnvironment(macCatalyst)
        return "\(prefix)/bin/apt-key"
        #else
        return "\(prefix)/usr/bin/apt-key"
        #endif
    }()

    // swiftlint:disable identifier_name
    static var sh: String = {
        "\(prefix)/bin/sh"
    }()

    static var sileolists: String = {
        return "\(prefix)/var/lib/apt/sileolists"
    }()

    static var lists: String = {
        return "\(prefix)/var/lib/apt/lists"
    }()

    static var whoami: String = {
        #if targetEnvironment(macCatalyst)
        "/usr/bin/whoami"
        #else
        if #available(iOS 13, *) {
            return "\(prefix)/usr/bin/whoami"
        }
        return "whoami"
        #endif
    }()

    static var uicache: String = {
        "\(prefix)/usr/bin/uicache"
    }()

    static var dpkgDir: URL = {
        #if targetEnvironment(simulator) || TARGET_SANDBOX
        return Bundle.main.bundleURL
        #else
        return URL(fileURLWithPath: "\(prefix)/Library/dpkg")
        #endif
    }()

    static var RepoIcon: String = {
        #if targetEnvironment(macCatalyst)
        return "RepoIcon"
        #else
        return "CydiaIcon"
        #endif
    }()

    static var group: String = {
        #if targetEnvironment(macCatalyst)
        return "\(NSUserName()):staff"
        #else
        return "mobile:mobile"
        #endif
    }()
    
    static var requiresDumbWorkaround: Bool = {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        if #available(iOS 15.0, *) {
            let archs = DpkgWrapper.getArchitectures
            if !archs.contains("iphoneos-arm64") && URL(fileURLWithPath: "/var/Liy").dirExists {
                return true
            }
        }
        return false
        #endif
    }()
    
}
