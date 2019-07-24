//
//  CommunicateUser.swift
//  Communicate
//
//  Created by Nicolas Degen on 18.06.19.
//  Copyright © 2019 Kapanu AG. All rights reserved.
//

import Foundation

public class CommunicateUser: Codable {
  public var Id: String
  public var Email: String
  public var IsApproved: Bool
  public var Name: String
  public var FirstName: String
  public var LastName: String
}

// Example
/*
 {
 "Id": "d9c05478-4a77-46c2-bd1f-5e52e6b520ae",
 "Email": "developer@kapanu.com",
 "IsApproved": true,
 "Name": "Kapanu Deb",
 "FirstName": "Kapanu",
 "LastName": "Developer",
 "PhoneNumber": "+41786694204",
 "MobilePhoneNumber": null,
 "ClientVersion": 0,
 "AddressLine": "Scheuchzerstrasse 44",
 "PostalCode": "8006",
 "Country": "CH",
 "City": "Zurich",
 "State": null,
 "RegionUri": "www.3shapecommunicate.com",
 "Region": {
 "Id": "0865f93d-38a5-412e-b23b-57342acc0b60",
 "RegionName": "Europe",
 "Url": "www.3shapecommunicate.com",
 "Servers": null,
 "Services": null
 },
 "Roles": [
 "Clinic"
 ],
 "ConnectedUsers": [],
 "Connections": [],
 "Dongles": [
 {
 "DongleNumber": null,
 "SiteId": null
 }
 ],
 "Tags": [],
 "HasLogo": true,
 "Logo": {
 "Href": "https://users.3shapecommunicate.com/api/users/d9c05478-4a77-46c2-bd1f-5e52e6b520ae/logo",
 "IsAvailable": true
 },
 "ContactName": null,
 "ContactEmail": null,
 "ContactPhoneNumber": null,
 "ContactConsentGiven": false,
 "NewsletterConsentGiven": false,
 "Website": null,
 "NotificationSettings": {}
 }
 */
