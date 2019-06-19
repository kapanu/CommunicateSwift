# CommunicateSwift
Swift Wrapper for 3Shape Communicate™ API

## Installation

- [X] Git submodule
- [ ] Carthage
- [ ] Swift Package

## Usage

```
import Communicate

Settings.shared.redirectionURI = "http://youruri.com"
Settings.shared.clientId = "YourClientId"
Settings.shared.clientSecret = "yourSecret"

Communicator.shared.signIn { status in
  print(status.message)
}

```
