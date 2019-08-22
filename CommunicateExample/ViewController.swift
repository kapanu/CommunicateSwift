//
//  ViewController.swift
//  CommunicateExample
//
//  Created by Nicolas Degen on 05.08.19.
//  Copyright © 2019 Kapanu AG. All rights reserved.
//

import UIKit

import Communicate

class ViewController: UIViewController {
  
  let nameLabel = UILabel(frame: CGRect(x: 199, y: 199, width: 100, height: 50))
  let redirectionURI = UITextField(frame: CGRect(x: 99, y: 299, width: 400, height: 50))
  let clientId = UITextField(frame: CGRect(x: 99, y: 399, width: 400, height: 50))
  let clientSecret = UITextField(frame: CGRect(x: 99, y: 499, width: 400, height: 50))
  
  let redirLabel = UILabel(frame: CGRect(x: 499, y: 299, width: 200, height: 50))
  let clientIdLabel = UILabel(frame: CGRect(x: 499, y: 399, width: 200, height: 50))
  let clientSecretLabel = UILabel(frame: CGRect(x: 499, y: 499, width: 200, height: 50))

  
  override func viewDidLoad() {
    super.viewDidLoad()
    
//    view.backgroundColor = .red
    Communicator.shared.redirectionURI =  UserDefaults.standard.string(forKey: "redirectionURI") ?? ""
    Communicator.shared.clientId = UserDefaults.standard.string(forKey: "ClientID") ?? ""
    Communicator.shared.clientSecret = UserDefaults.standard.string(forKey: "clientSecret") ?? ""
    
    view.addSubview(redirectionURI)
    redirectionURI.borderStyle = .roundedRect
    redirectionURI.text = Communicator.shared.redirectionURI
    
    view.addSubview(clientId)
    clientId.borderStyle = .roundedRect
    clientId.text = Communicator.shared.clientId
    
    view.addSubview(clientSecret)
    clientSecret.borderStyle = .roundedRect
    clientSecret.text = Communicator.shared.clientSecret
    
    view.addSubview(redirLabel)
    redirLabel.textColor = .lightGray
    redirLabel.text = "Enter your redirection URI"
    view.addSubview(clientIdLabel)
    clientIdLabel.textColor = .lightGray
    clientIdLabel.text = "Enter your ClientID"
    view.addSubview(clientSecretLabel)
    clientSecretLabel.textColor = .lightGray
    clientSecretLabel.text = "Enter your ClientSecret"
    
    
    
    let setCredentialsButton = UIButton(frame: CGRect(x: 99, y: 599, width: 200, height: 50))
    view.addSubview(setCredentialsButton)
    setCredentialsButton.setTitle("Set Credentials", for: .normal)
    setCredentialsButton.addTarget(self, action: #selector(setCredentials), for: .touchDown)
    
    let signin = UIButton(frame: CGRect(x: 99, y: 99, width: 100, height: 50))
    view.addSubview(signin)
    signin.setTitle("Sign In", for: .normal)
    signin.addTarget(self, action: #selector(signIn), for: .touchDown)
    
    let refreshBtn = UIButton(frame: CGRect(x: 399, y: 199, width: 300, height: 50))
    view.addSubview(refreshBtn)
    refreshBtn.setTitle("Refresh", for: .normal)
    refreshBtn.addTarget(self, action: #selector(refresh), for: .touchDown)
    
    let getDataBtn = UIButton(frame: CGRect(x: 99, y: 199, width: 300, height: 50))
    view.addSubview(getDataBtn)
    getDataBtn.setTitle("Query user data and cases", for: .normal)
    getDataBtn.addTarget(self, action: #selector(getData), for: .touchDown)
    
    view.addSubview(nameLabel)
  }
  
  @objc func setCredentials() {
    Communicator.shared.redirectionURI = redirectionURI.text ?? ""
    UserDefaults.standard.set(Communicator.shared.redirectionURI, forKey: "redirectionURI")
    
    Communicator.shared.clientId = clientId.text ?? ""
    UserDefaults.standard.set(Communicator.shared.clientId, forKey: "ClientID")
    
    Communicator.shared.clientSecret = clientSecret.text ?? ""
    UserDefaults.standard.set(Communicator.shared.clientSecret, forKey: "clientSecret")
  }
  
  @objc func signIn() {
    Communicator.shared.signIn { status in
      
    }
  }
  
  @objc func refresh() {
    Communicator.shared.refreshToken { status in
      print(status)
    }
  }
  
  @objc func getData() {
    Communicator.shared.queryCurrentUserData { user in
      DispatchQueue.main.async {
        self.nameLabel.text = user.Name
      }
    }
    Communicator.shared.retrieveCases { data in
      let cases = try! data.get()
      let goodCase = cases.first {$0.id == "056bae09-d328-4240-96b0-4d20a23dca88"}
      Communicator.shared.getCaseModel(forCase: goodCase!, completion: { caseModel in
        let a = caseModel!.stages.first!.getToothTransforms()
        print(a.first?.value)
      })
      print(cases[2].attachments[2].href)
    }
  }
}

