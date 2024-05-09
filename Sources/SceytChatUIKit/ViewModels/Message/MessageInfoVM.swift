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
	private let localizedMarkerNames: [String: String]
	
	var markers: [(markerName: String, markerArray: [ChatMessage.Marker])] {
		var markersArray: [(markerName: String, markerArray: [ChatMessage.Marker])] = []
		
		markerObserver.items.forEach { marker in
			if let index = markersArray.firstIndex(where: { $0.markerName == marker.name }) {
				markersArray[index].markerArray.append(marker)
			} else {
				markersArray.append((markerName: marker.name, markerArray: [marker]))
			}
		}
		
		if let displayedIndex = markersArray.firstIndex(where: { $0.markerName == DefaultMarker.displayed.rawValue }),
		   let receivedIndex = markersArray.firstIndex(where: { $0.markerName == DefaultMarker.received.rawValue }) {
			for displayedMarker in markersArray[displayedIndex].markerArray {
				markersArray[receivedIndex].markerArray.removeAll { $0.user?.id == displayedMarker.user?.id }
				if markersArray[receivedIndex].markerArray.isEmpty {
					markersArray.remove(at: receivedIndex)
				}
			}
		}
		
		markersArray.sort { DefaultMarker(rawValue: $0.markerName) ?? .played < DefaultMarker(rawValue: $1.markerName) ?? .played }
		
		return markersArray
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
		localizedMarkerNames: [String: String]? = nil)
	{
		self.messageMarkerProvider = messageMarkerProvider
		self.data = data
		let markerNames = markerNames ?? [DefaultMarker.displayed.rawValue, DefaultMarker.received.rawValue, DefaultMarker.played.rawValue]
		self.localizedMarkerNames = localizedMarkerNames ?? [DefaultMarker.displayed.rawValue: L10n.Message.Info.readBy,
															 DefaultMarker.received.rawValue: L10n.Message.Info.deliveredTo,
															 DefaultMarker.played.rawValue: L10n.Message.Info.playedBy]
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
		event = .reload
//		let calculatedIndices = calculateIndexPaths(for: items)
//		if markerObserver.isEmpty || items.inserts.isEmpty || calculatedIndices.isEmpty {
//			event = .reload
//			return
//		}
//		
//		event = .insert(calculatedIndices)
	}
	
//	private func calculateIndexPaths(for items: DBChangeItemPaths) -> [IndexPath] {
//		var correctIndexPaths: [IndexPath] = []
//		
//		guard let changedMarkers: [ChatMessage.Marker] = items.items() else { return [] }
//		
//		self.markers.enumerated().forEach { (section, markers) in
//			markers.markerArray.enumerated().forEach { (index, marker) in
//				if changedMarkers.contains(where: { $0 == marker }) {
//					correctIndexPaths.append(IndexPath(row: index, section: section + 1))
//				}
//			}
//		}
//		
//		return correctIndexPaths
//	}
}

extension MessageInfoVM {

	open var numberOfSections: Int { markers.count + 1 }
    
    open func numberOfRows(section: Int) -> Int {
		switch section {
		case 0: return 1
		default: return markers[section - 1].markerArray.count
		}
    }
    
    open func header(section: Int) -> String? {
        guard numberOfRows(section: section) > 0
        else { return nil }
        
        switch section {
		case 0: return nil
		default: return localizedMarkerNames[markers[section - 1].markerName]
        }
    }
    
    open func marker(at indexPath: IndexPath) -> ChatMessage.Marker? {
		switch indexPath.section {
		case 0: nil
		default: markers[indexPath.section - 1].markerArray[indexPath.row]
		}
    }
}

public extension MessageInfoVM {
    enum Event {
        case reload
//		case insert([IndexPath])
    }
}
