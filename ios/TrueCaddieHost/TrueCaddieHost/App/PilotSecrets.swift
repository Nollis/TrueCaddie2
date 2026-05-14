//
//  PilotSecrets.swift
//  TrueCaddieHost
//
//  Local-only realtime API key for the pilot.
//
//  HOW TO USE
//  ----------
//  Replace `nil` below with your "sk-..." key (as a string literal) when you
//  want the host app to actually open the realtime websocket. The committed
//  copy of this file must always have `realtimeAPIKey = nil`.
//
//  After you paste your key, run this once in the repo so git stops
//  tracking changes to this file on your machine:
//
//      git update-index --skip-worktree ios/TrueCaddieHost/TrueCaddieHost/App/PilotSecrets.swift
//
//  To re-enable tracking later:
//
//      git update-index --no-skip-worktree ios/TrueCaddieHost/TrueCaddieHost/App/PilotSecrets.swift
//
//  DO NOT COMMIT A REAL KEY. If a key ends up in a commit, revoke it
//  immediately at https://platform.openai.com/api-keys and issue a new one.
//

import Foundation

enum PilotSecrets {
    static let realtimeAPIKey: String? = nil
}
