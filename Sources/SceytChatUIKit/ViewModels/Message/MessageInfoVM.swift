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
	
	@Published public var event: Event?
	
	public let data: MessageLayoutModel
	private let queries: [MessageMarkerListQuery]
	private let localizedMarkerNames: [String]?
	
	var markers: [String: [ChatMessage.Marker]] {
		var markers: [String: [ChatMessage.Marker]] = [:]
		markerObserver.items.map { marker in
			if markers[marker.name] == nil {
				markers[marker.name] = []
			}
			markers[marker.name]?.append(marker)
		}
		return markers
	}
	
	public private(set) var messageMarkerProvider: ChannelMessageMarkerProvider
	
	public private(set) lazy var markerObserver: DatabaseObserver<MarkerDTO, ChatMessage.Marker> = {
		let predicate = NSPredicate(format: "messageId == %lld AND user.id != %@", data.message.id, data.message.user.id)
		
		return DatabaseObserver<MarkerDTO, ChatMessage.Marker>(
			request: MarkerDTO.fetchRequest()
				.sort(descriptors: [.init(keyPath: \MarkerDTO.createdAt, ascending: false)])
				.fetch(predicate: predicate),
			context: Config.database.viewContext)
		{ $0.convert() }
	}()
	
	public required init(
		messageMarkerProvider: ChannelMessageMarkerProvider,
		data: MessageLayoutModel,
		markerNames: [String]? = nil,
		localizedMarkerNames: [String]? = nil)
	{
		self.messageMarkerProvider = messageMarkerProvider
		self.data = data
		let markerNames = markerNames ?? [DefaultMarker.displayed, DefaultMarker.received, DefaultMarker.played]
		self.localizedMarkerNames = localizedMarkerNames ?? [L10n.Message.Info.readBy, L10n.Message.Info.deliveredTo, L10n.Message.Info.playedBy]
		self.queries = markerNames.map {
			.Builder(messageId: data.message.id, markerName: $0)
			.build()
		}
		super.init()
	}
}

extension MessageInfoVM {
	
	open func loadMarkers() {
		guard !queries.isEmpty else { return }
		for query in queries {
			messageMarkerProvider.loadMarkers(query)
		}
	}
	
	open func startDatabaseObserver() {
		markerObserver.onDidChange = { [weak self] in
			self?.onDidChangeEvent(items: $0)
		}
		do {
			try markerObserver.startObserver()
		} catch {
			logger.errorIfNotNil(error, "observer.startObserver")
		}
	}
	
	open func onDidChangeEvent(items: DBChangeItemPaths) {
		if markerObserver.isEmpty || items.inserts.isEmpty {
			event = .reload
			return
		}
		
		event = .insert(calculateIndexPaths(for: items))
	}
	
	private func calculateIndexPaths(for items: DBChangeItemPaths) -> [IndexPath] {
		var correctIndexPaths: [IndexPath] = []
		
		let markers: [ChatMessage.Marker]? = items.items()
		
		markers?.forEach({ marker in
			var index = 0
			queries.enumerated().forEach { (section, query) in
				if query.markerName == marker.name {
					correctIndexPaths.append(IndexPath(row: index, section: section + 1))
					index += 1
				}
			}
		})
		
		return correctIndexPaths
	}
}

extension MessageInfoVM {

	open var numberOfSections: Int { queries.count + 1 }
    
    open func numberOfRows(section: Int) -> Int {
		switch section {
		case 0: return 1
		default: return markers[queries[section - 1].markerName]?.count ?? 0
		}
    }
    
    open func header(section: Int) -> String? {
        guard numberOfRows(section: section) > 0
        else { return nil }
        
        switch section {
		case 0: return nil
		default: return localizedMarkerNames?[section - 1]
        }
    }
    
    open func marker(at indexPath: IndexPath) -> ChatMessage.Marker? {
		switch indexPath.section {
		case 0: nil
		default: markers[queries[indexPath.section - 1].markerName]?[indexPath.row]
		}
    }
    
//    open func filter() {
//        var markers = self.markers
//        read.forEach { marker in
//            markers.forEach { key, value in
//                if key != DefaultMarker.displayed {
//                    var value = value
//                    value.removeAll(where: { $0.user?.id == marker.user?.id })
//                    markers[key] = value
//                }
//            }
//        }
//        self.markers = markers
//    }
}

public extension MessageInfoVM {
    enum Event {
        case reload
		case insert([IndexPath])
    }
}
