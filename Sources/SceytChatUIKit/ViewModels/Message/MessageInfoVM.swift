//
//  MessageInfoVM.swift
//  SceytChatUIKit
//
//  Created by Duc on 21/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Combine
import SceytChat

open class MessageInfoVM: NSObject {
    public let data: MessageLayoutModel
    private let queries: [MessageMarkerListQuery]
    private(set) var markers = [String: [ChatMessage.Marker]]()
    
    public required init(
        data: MessageLayoutModel,
        markerNames: [String]? = nil)
    {
        self.data = data
        let markerNames = markerNames ?? [DefaultMarker.displayed, DefaultMarker.received]
        self.queries = markerNames.map {
            .Builder(messageId: data.message.id, markerName: $0)
                .build()
        }
        super.init()
        
        if !queries.isEmpty {
            let group = DispatchGroup()
            for query in queries {
                group.enter()
                Task {
                    await loadMarkers(query)
                    group.leave()
                }
            }
            group.notify(queue: .main) { [weak self] in
                guard let self else { return }
                filter()
                self.event = .reload
            }
        }
    }
    
    @Published public var event: Event?
    
    private var read: [ChatMessage.Marker] { markers[DefaultMarker.displayed] ?? [] }
    private var delivered: [ChatMessage.Marker] { markers[DefaultMarker.received] ?? [] }
    
    open var numberOfSections: Int { 3 }
    
    open func numberOfRows(section: Int) -> Int {
        switch section {
        case 1: return read.count
        case 2: return delivered.count
        default: return 1
        }
    }
    
    open func header(section: Int) -> String? {
        guard numberOfRows(section: section) > 0
        else { return nil }
        
        switch section {
        case 1: return L10n.Message.Info.readBy
        case 2: return L10n.Message.Info.deliveredTo
        default: return nil
        }
    }
    
    open func marker(at indexPath: IndexPath) -> ChatMessage.Marker? {
        switch indexPath.section {
        case 1: return read[indexPath.row]
        case 2: return delivered[indexPath.row]
        default: return nil
        }
    }
    
    open func loadMarkers(_ query: MessageMarkerListQuery) async {
        guard query.hasNext, !query.loading else { return }
        do {
            try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, Error>) in
                query.loadNext { [weak self] q, markers, error in
                    guard let self else {
                        return continuation.resume(returning: ())
                    }
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        if let markers {
                            if self.markers[q.markerName] == nil {
                                self.markers[q.markerName] = []
                            }
                            self.markers[q.markerName]?.append(contentsOf: markers.map { ChatMessage.Marker(marker: $0) })
                        }
                        continuation.resume(returning: ())
                    }
                }
            }
        } catch {
            logger.errorIfNotNil(error, "")
        }
    }
    
    open func loadNext(_ section: Int) {
        if section == 0 { return }
        if queries.count < section - 1 { return }
        let query = queries[section - 1]
        guard query.hasNext, !query.loading else { return }
        Task {
            await loadMarkers(query)
            filter()
            event = .reload
        }
    }
    
    open func filter() {
        var markers = self.markers
        read.forEach { marker in
            markers.forEach { key, value in
                if key != DefaultMarker.displayed {
                    var value = value
                    value.removeAll(where: { $0.user?.id == marker.user?.id })
                    markers[key] = value
                }
            }
        }
        self.markers = markers
    }
}

public extension MessageInfoVM {
    enum Event {
        case reload
    }
}
