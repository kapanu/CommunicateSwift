//
//  CommunicateTests.swift
//  CommunicateTests
//
//  Created by Nicolas Degen on 20.08.19.
//  Copyright © 2019 Kapanu AG. All rights reserved.
//

import XCTest

import WebKit

import Communicate

class CommunicateTests: XCTestCase, WKNavigationDelegate {
  
  var signinExpectation: XCTestExpectation!
  
  override func setUp() {
    Communicator.shared.clientId = "IvoSmileTest"
    Communicator.shared.redirectionURI = "https://3shapecommunicate.test.com"
    Communicator.shared.clientSecret = "hXzoGXVDsU1yh7J7HYNR"
  }
  
  override func tearDown() {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }
  
  func testSingIn() {
    let webview = WKWebView(frame: CGRect(x: 0, y: 0, width: 600, height: 600))
    webview.navigationDelegate = self
    let url = Communicator.shared.identityURL
    webview.load(URLRequest(url: url))
    self.signinExpectation = self.expectation(description: #function)
    
    waitForExpectations(timeout: 34)
  }
  
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    print("End loading")
    webView.evaluateJavaScript("document.getElementById('Email').value = 'developer@kapanu.com';")
    webView.evaluateJavaScript("document.getElementById('Password').value = 'CommunicateTest1';")
    webView.evaluateJavaScript("""
var buttons = document.querySelectorAll('button');
for (var i=0, l=buttons.length; i<l; i++) {
    if (buttons[i].firstChild.nodeValue == "Sign in") {
        buttons[i].click();
    }
}
console.log('Clicked Sign in!');
""")
  }
  
  public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    let requestDescription = navigationAction.request.description
    print(navigationAction.request.mainDocumentURL!)
    if navigationAction.request.mainDocumentURL!.host!.contains("test.com") {
      decisionHandler(.cancel)
      if let range = requestDescription.range(of: "https://3shapecommunicate.test.com/?code=") {
        let authCode = String(requestDescription[range.upperBound...])
        let communicator = Communicator.shared
        communicator.requestToken(authCode: authCode) { status in
          if status == .signedIn {
            self.signinExpectation.fulfill()
          }
        }
      }
      return
    }
    decisionHandler(.allow)
  }
}
