//
//  BaseService.swift
//  RwiftUI
//
//  Created by thawdezin on 6/13/25.
//

enum APIError: Error, Equatable {
    case tokenExpired
    case missingRefreshToken
    case invalidUrl
    case invalidCompanyCode
    case invalidLoginId
    case invalidDepartment
    case invalidLoginData
    case invalidResponse
    case customError(message: String)
}


