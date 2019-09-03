//
//  AuthenticationViewController.swift
//  CommunicateSwift
//
//  Created by Nicolas Degen on 17.06.19.
//  Copyright © 2019 Kapanu AG. All rights reserved.
//

import UIKit
import WebKit

public class AuthenticationViewController: UIViewController {
  
  let webview = WKWebView(frame: .zero)
  
  var completionCallback: ((CommunicateStatus)->())?
  
  override public func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
    view.addSubview(webview)
    webview.translatesAutoresizingMaskIntoConstraints = false
    webview.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    webview.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
    webview.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
    webview.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    webview.navigationDelegate = self
    webview.load(URLRequest(url: Settings.shared.identityURL))
  }
}

extension AuthenticationViewController: WKNavigationDelegate {
  public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    let requestDescription = navigationAction.request.description
    if navigationAction.request.mainDocumentURL!.host! == URL(string: Settings.shared.redirectionURI)!.host! {
      decisionHandler(.cancel)
      if let range = requestDescription.range(of: Settings.shared.redirectionURI + "/?code=") {
        let authCode = String(requestDescription[range.upperBound...])
        let communicator = Communicator.shared
        communicator.requestToken(authCode: authCode) { status in
          self.dismiss(animated: true) {
            self.completionCallback?(status)
          }
        }
      }
      return
    }
    decisionHandler(.allow)
  }
}


