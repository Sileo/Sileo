//
//  Data+Extensions.swift
//  Sileo
//
//  Created by Somica on 25/07/2022.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

extension Data {
     func append(to fileURL: URL) throws {
         if let handle = FileHandle(forWritingAtPath: fileURL.path) {
             defer {
                 handle.closeFile()
             }
             handle.seekToEndOfFile()
             handle.write(self)
         }
         else {
             try write(to: fileURL, options: .atomic)
         }
     }
 }
