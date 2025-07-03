//
//  webview_cookie_manager_exampleTests.swift
//  webview_cookie_manager_exampleTests
//
//  Created by Никита Красавин on 28.02.2021.
//

import XCTest
import webview_cookie_manager

class webview_cookie_manager_exampleTests: XCTestCase {
    override class func setUp() {
        super.setUp()
    }

    override class func tearDown() {
        super.tearDown()
    }

    func testCookieWithoutDomainAttribute() throws {
        let cookie = ["name": "cookie_name", "value": "cookie_value"] as NSDictionary
        SwiftWebviewCookieManagerPlugin.setCookies(cookies: [cookie], result: { _ in })
    }
}
