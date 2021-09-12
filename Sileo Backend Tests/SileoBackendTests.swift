//
//  Sileo_Backend_Tests.swift
//  Sileo Backend Tests
//
//  Created by Andromeda on 05/08/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

import XCTest
import Foundation
@testable import Sileo

class SileoBackendTests: XCTestCase {

    var observer: NSObjectProtocol?
    
    override func tearDown() {
        super.tearDown()
        DispatchQueue.main.async {
            let repoMan = RepoManager.shared
            
            let repos = repoMan.repoList
            for repo in repos {
                repoMan.remove(repo: repo)
            }
            
            NotificationCenter.default.removeObserver(self.observer as Any)
        }
    }
    
    func testARepoRefresh() throws {
        let repoMan = RepoManager.shared
        
        let repos = repoMan.repoList
        for repo in repos {
            repoMan.remove(repo: repo)
        }
        
        let reposToAdd = [
            URL(string: "https://beta.apptapp.me/")!,
            URL(string: "https://repo.theodyssey.dev/")!,
            URL(string: "https://repo.twickd.com/")!,
            URL(string: "https://repo.elihc.dev")!,
            URL(string: "https://repo.chariz.com/")!,
            URL(string: "https://repo.packix.com")!,
            URL(string: "https://isecureos.idevicecentral.com/repo/")!,
            URL(string: "https://nscake.github.io/")!,
            URL(string: "https://sarahh12099.github.io/repo/")!,
            URL(string: "https://skitty.xyz/repo")!,
            URL(string: "https://getzbra.com/repo")!,
            URL(string: "http://junesiphone.com/supersecret")!,
            URL(string: "https://repo.icrazeios.com/")!,
            URL(string: "https://thealphastream.github.io/repo")!,
            URL(string: "https://www.monotrix.xyz/")!,
            URL(string: "https://repo.meth.love/")!,
            URL(string: "https://sparkdev.me")!,
            URL(string: "https://apt.tale.me")!
        ]
        repoMan.addRepos(with: reposToAdd)
        
        let promise = expectation(description: "Repo Refresh")
        var fulfilled = false
        
        repoMan.update(force: true, forceReload: true, isBackground: false, completion: { didFindErrors, errorOutput in
            DispatchQueue.main.async {
                let repos = repoMan.repoList
                
                var shouldFinish = true
                for repo in repos where !repo.isLoaded || repo.startedRefresh || repo.totalProgress != 0 {
                    shouldFinish = false
                }
                
                if didFindErrors {
                    XCTAssertFalse(didFindErrors, errorOutput.string)
                }
                if shouldFinish && !fulfilled {
                    promise.fulfill()
                    fulfilled = true
                }
            }
        })
        
        waitForExpectations(timeout: 30)
    }
    
    func testBAddQueue() throws {
        let allPackages = PackageListManager.shared.allPackagesArray
        guard !allPackages.isEmpty else {
            XCTAssert(false, "All Packages is Empty")
            throw "All Packages is Empty"
        }
        
        let downloadMan = DownloadManager.shared
        let bundlesToInstall = [
            "org.coolstar.libhooker",
            "org.swift.libswift",
            "com.megadev.sentinel",
            "com.amywhile.signalreborn",
            "com.spark.snowboard",
            "me.tale.panic",
            "ws.hbang.newterm2",
            "me.aspenuwu.zinnia.trial",
            "com.amywhile.ccpatch13",
            "com.spark.kaleidoscope"
        ]
        
        for bundle in bundlesToInstall {
            guard let package = allPackages.first(where: { $0.package == bundle }) else {
                XCTAssert(false, "Could not find package: \(bundle)")
                throw "Could not find package: \(bundle)"
            }
            downloadMan.add(package: package, queue: .installations)
        }
    }
    
    func testCQueueInstall() throws {
        let promise = expectation(description: "Package Downloads and Install")
        let downloadMan = DownloadManager.shared
        
        downloadMan.viewController.confirmQueued(nil)
        
        self.observer = NotificationCenter.default.addObserver(forName: NSNotification.Name("SileoTests.CompleteInstall"), object: nil, queue: nil) { _ in
            promise.fulfill()
            return
        }
        
        waitForExpectations(timeout: 120) { _ in
            let errors = downloadMan.errors
            XCTAssert(errors.isEmpty, "Failed with the errors \(errors)")
        }
    }
}
