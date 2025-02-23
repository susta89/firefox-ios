// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Sync
import Shared
import Storage

public enum SyncDisplayState {
    case inProgress
    case good
    case bad(message: String?)
    case warning(message: String)

    func asObject() -> [String: String]? {
        switch self {
        case .bad(let msg):
            guard let message = msg else {
                return ["state": "Error"]
            }
            return ["state": "Error",
                    "message": message]
        case .warning(let message):
            return ["state": "Warning",
                    "message": message]
        default:
            break
        }
        return nil
    }
}

public func == (lhs: SyncDisplayState, rhs: SyncDisplayState) -> Bool {
    switch (lhs, rhs) {
    case (.inProgress, .inProgress):
        return true
    case (.good, .good):
        return true
    case (.bad(let first), .bad(let second)) where first == second:
        return true
    case (.warning(let first), .warning(let second)) where first == second:
        return true
    default:
        return false
    }
}

/*
 * Translates the fine-grained SyncStatuses of each sync engine into a more coarse-grained
 * display-oriented state for displaying warnings/errors to the user.
 */
public struct SyncStatusResolver {

    let engineResults: Maybe<EngineResults>

    public func resolveResults() -> SyncDisplayState {
        guard let results = engineResults.successValue else {
            return SyncDisplayState.bad(message: nil)
        }

        // Run through the engine results and produce a relevant display status for each one
        let displayStates: [SyncDisplayState] = results.map { (engineIdentifier, syncStatus) in
            print("Sync status for \(engineIdentifier): \(syncStatus)")

            // Explicitly call out each of the enum cases to let us lean on the compiler when
            // we add new error states
            switch syncStatus {
            case .notStarted(let reason):
                switch reason {
                case .offline:
                    return .bad(message: .FirefoxSyncOfflineTitle)
                case .noAccount:
                    return .warning(message: .FirefoxSyncOfflineTitle)
                case .backoff:
                    return .good
                case .engineRemotelyNotEnabled:
                    return .good
                case .engineFormatOutdated:
                    return .good
                case .engineFormatTooNew:
                    return .good
                case .storageFormatOutdated:
                    return .good
                case .storageFormatTooNew:
                    return .good
                case .stateMachineNotReady:
                    return .good
                case .redLight:
                    return .good
                case .unknown:
                    return .good
                }
            case .completed:
                return .good
            case .partial:
                return .good
            }
        }

        // TODO: Instead of finding the worst offender in a list of statuses, we should better surface
        // what might have happened with a particular engine when syncing.
        let aggregate: SyncDisplayState = displayStates.reduce(.good) { carried, displayState in
            switch displayState {

            case .bad:
                return displayState

            case .warning:
                // If the state we're carrying is worse than the stale one, keep passing
                // along the worst one
                switch carried {
                case .bad:
                    return carried
                default:
                    return displayState
                }
            default:
                // This one is good so just pass on what was being carried
                return carried
            }
        }

        print("Resolved sync display state: \(aggregate)")
        return aggregate
    }
}
