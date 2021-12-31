//
//  LogStreamViewController.swift
//  Sileo
//
//  Created by Amy While on 31/12/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

import UIKit

final class StandardOutputStream: TextOutputStream {
    static let shared = StandardOutputStream()
    private let fileHandle = FileHandle(fileDescriptor: LogStreamViewController._shared.outputFd[1])
    func write(_ string: String) {
        fileHandle.write(Data(string.utf8))
    }
}

final class StandardErrorOutputStream: TextOutputStream {
    static let shared = StandardErrorOutputStream()
    private let fileHandle = FileHandle(fileDescriptor: LogStreamViewController._shared.errFd[1])
    func write(_ string: String) {
        fileHandle.write(Data(string.utf8))
    }
}

private var debugOutput = StandardOutputStream.shared
func debugPrint(items: Any...) {
    print(items, to: &debugOutput)
}

@_cdecl("logger_stdout")
func logger_stdout() -> Int32 {
    LogStreamViewController._shared.outputFd[1]
}

@_cdecl("logger_stderr")
func logger_stderr() -> Int32 {
    LogStreamViewController._shared.errFd[1]
}

public class LogStreamViewController: UIViewController {
    
    static public let shared: UINavigationController = {
        SileoNavigationController(rootViewController: LogStreamViewController())
    }()
    fileprivate static let _shared: LogStreamViewController = {
        LogStreamViewController.shared.viewControllers[0] as! LogStreamViewController
    }()
    
    private(set) var outputFd: [Int32] = [0, 0]
    private(set) var errFd: [Int32] = [0, 0]
    
    private let readQueue = DispatchQueue(label: "org.coolstar.sileo.logstream",
                                          qos: .userInteractive,
                                          attributes: .concurrent,
                                          autoreleaseFrequency: .inherit,
                                          target: nil)
    
    private let outputSource: DispatchSourceRead
    private let errorSource: DispatchSourceRead
    
    public var textView: UITextView = {
        let textView = UITextView(frame: .zero)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isSelectable = false
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets.zero
        textView.textContainer.lineFragmentPadding = 0
        if #available(iOS 13.0, *) {
            textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        } else {
            textView.font = UIFont.systemFont(ofSize: 14)
        }
        textView.textColor = .green
        textView.layoutManager.allowsNonContiguousLayout = false
        return textView
    }()
    
    init() {
        guard pipe(&outputFd) != -1,
            pipe(&errFd) != -1 else {
                fatalError("pipe failed")
        }
        
        let origOutput = dup(STDOUT_FILENO)
        let origErr = dup(STDERR_FILENO)
        
        setvbuf(stdout, nil, _IONBF, 0)
        
        guard dup2(outputFd[1], STDOUT_FILENO) >= 0,
            dup2(errFd[1], STDERR_FILENO) >= 0 else {
                fatalError("dup2 failed")
        }
        
        outputSource = DispatchSource.makeReadSource(fileDescriptor: outputFd[0], queue: readQueue)
        errorSource = DispatchSource.makeReadSource(fileDescriptor: errFd[0], queue: readQueue)
        
        super.init(nibName: nil, bundle: nil)
        
        outputSource.setCancelHandler {
            close(self.outputFd[0])
            close(self.outputFd[1])
        }
        
        errorSource.setCancelHandler {
            close(self.errFd[0])
            close(self.errFd[1])
        }
        
        let bufsiz = Int(BUFSIZ)
        
        outputSource.setEventHandler {
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufsiz)
            defer { buffer.deallocate() }
            
            let bytesRead = read(self.outputFd[0], buffer, bufsiz)
            guard bytesRead > 0 else {
                if bytesRead == -1 && errno == EAGAIN {
                    return
                }
                
                self.outputSource.cancel()
                return
            }
            write(origOutput, buffer, bytesRead)
            
            let array = Array(UnsafeBufferPointer(start: buffer, count: bytesRead)) + [UInt8(0)]
            array.withUnsafeBufferPointer { ptr in
                let str = String(cString: unsafeBitCast(ptr.baseAddress, to: UnsafePointer<CChar>.self))
                self.add(text: str)
            }
        }
        
        errorSource.setEventHandler {
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufsiz)
            defer { buffer.deallocate() }
            
            let bytesRead = read(self.errFd[0], buffer, bufsiz)
            guard bytesRead > 0 else {
                if bytesRead == -1 && errno == EAGAIN {
                    return
                }
                
                self.errorSource.cancel()
                return
            }
            write(origErr, buffer, bytesRead)
            
            let array = Array(UnsafeBufferPointer(start: buffer, count: bytesRead)) + [UInt8(0)]
            array.withUnsafeBufferPointer { ptr in
                let str = String(cString: unsafeBitCast(ptr.baseAddress, to: UnsafePointer<CChar>.self))
                self.add(text: str)
            }
        }
        
        outputSource.resume()
        errorSource.resume()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.view.backgroundColor = .clear
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: String(localizationKey: "Close"), style: .done, target: self, action: #selector(pop))
        
        view.addSubview(textView)
        view.backgroundColor = .black
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 5),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -5),
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 5),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -5)
        ])
    }
    
    @objc private func pop() {
        self.dismiss(animated: true)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func add(text: String) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.add(text: text)
            }
            return
        }
        textView.text = (textView.text ?? "") + "\(text)\n"
        let point = CGPoint(x: 0, y: textView.contentSize.height - textView.bounds.size.height)
        textView.setContentOffset(point, animated: false)
    }
    
}

