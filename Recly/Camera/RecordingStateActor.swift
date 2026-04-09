//
//  Actor.swift
//  Recly
//
//  Created by Gustavo Souto Pereira on 09/04/26.
//

import Foundation
import SwiftUI

actor RecordingStateActor {
    enum State {
        case idle
        case starting
        case recording
        case stopping
    }
    
    private var state: State = .idle
    private var lastActionDate = Date()
    
    func canStartRecording() -> Bool {
        guard state == .idle else { return false }
        return debounce()
    }
    
    func canStopRecording() -> Bool {
        guard state == .recording else { return false }
        return debounce()
    }
    
    func setState(_ newState: State) {
        state = newState
    }
    
    func getState() -> State {
        return state
    }
    
    private func debounce() -> Bool {
        let now = Date()
        defer { lastActionDate = now }
        return now.timeIntervalSince(lastActionDate) > 0.4
    }
}
