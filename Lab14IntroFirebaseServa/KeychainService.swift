//
//  KeychainService.swift
//  Lab14IntroFirebaseServa
//
//  Created by Codex on 7/2/26.
//

import Foundation
import Security

enum KeychainService {
    private static let service = "com.sergioserva.Lab14IntroFirebaseServa.docentehub"

    static func save(value: String, account: String) -> Bool {
        let data = Data(value.utf8)
        let query = baseQuery(account: account)

        SecItemDelete(query as CFDictionary)

        var updatedQuery = query
        updatedQuery[kSecValueData as String] = data

        return SecItemAdd(updatedQuery as CFDictionary, nil) == errSecSuccess
    }

    static func load(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard
            status == errSecSuccess,
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return value
    }

    static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    private static func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
