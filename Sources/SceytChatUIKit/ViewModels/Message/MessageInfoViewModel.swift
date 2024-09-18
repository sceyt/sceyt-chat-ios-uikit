//
//  MessageInfoViewModel.swift
//  SceytChatUIKit
//
//  Created by Duc on 21/10/2023.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import Combine
import SceytChat

open class MessageInfoViewModel: NSObject {
	
	@Published public var event: Event?
	
	public let data: MessageLayoutModel
	private let queries: [MessageMarkerListQuery]
	private let localizedMarkerNames: [DefaultMarker: String]
    public var queryLimit: UInt
	
    public var markers: [(markerName: String, markerArray: [ChatMessage.Marker])] {
		var markersArray: [(markerName: String, markerArray: [ChatMessage.Marker])] = []
		
		markerObserver.items.forEach { marker in
			if let index = markersArray.firstIndex(where: { $0.markerName == marker.name }) {
				markersArray[index].markerArray.append(marker)
			} else {
				markersArray.append((markerName: marker.name, markerArray: [marker]))
			}
		}
		
		// remove displayed markers from received
        
        
		if let displayedMarkersArrayIndex = markersArray.firstIndex(where: { $0.markerName == DefaultMarker.displayed.rawValue }),
		   let receivedMarkersArrayIndex = markersArray.firstIndex(where: { $0.markerName == DefaultMarker.received.rawValue }) {
            displayedMarkersLoop: for displayedMarker in markersArray[displayedMarkersArrayIndex].markerArray {
                receivedMarkersLoop: for (receivedMarkerIndex, receivedMarker) in markersArray[receivedMarkersArrayIndex].markerArray.enumerated() {
                    if receivedMarker.user?.id == displayedMarker.user?.id {
                        markersArray[receivedMarkersArrayIndex].markerArray.remove(at: receivedMarkerIndex)
                        if markersArray[receivedMarkersArrayIndex].markerArray.isEmpty {
                            markersArray.remove(at: receivedMarkersArrayIndex)
                            break displayedMarkersLoop
                        }
                        break receivedMarkersLoop
                    }
                }
            }
		}
		
		// remove played markers from displayed
		if let playedMarkersArrayIndex = markersArray.firstIndex(where: { $0.markerName == DefaultMarker.played.rawValue }),
		   let displayedMarkersArrayIndex = markersArray.firstIndex(where: { $0.markerName == DefaultMarker.displayed.rawValue }) {
            playedMarkersLoop: for playedMarker in markersArray[playedMarkersArrayIndex].markerArray {
                displayedMarkersLoop: for (displayedMarkerIndex, displayedMarker) in markersArray[displayedMarkersArrayIndex].markerArray.enumerated() {
                    if displayedMarker.user?.id == playedMarker.user?.id {
                        markersArray[displayedMarkersArrayIndex].markerArray.remove(at: displayedMarkerIndex)
                        if markersArray[displayedMarkersArrayIndex].markerArray.isEmpty {
                            markersArray.remove(at: displayedMarkersArrayIndex)
                            break playedMarkersLoop
                        }
                        break displayedMarkersLoop
                    }
                }
			}
		}
		
		markersArray.sort { DefaultMarker(rawValue: $0.markerName) > DefaultMarker(rawValue: $1.markerName) }
		
		return markersArray
	}
	
    open var messageMarkerProvider: ChannelMessageMarkerProvider
	
    open lazy var markerObserver: DatabaseObserver<MarkerDTO, ChatMessage.Marker> = {
		let predicate = NSPredicate(format: "messageId == %lld AND user.id != %@", data.message.id, data.message.user.id)
		
		return DatabaseObserver<MarkerDTO, ChatMessage.Marker>(
			request: MarkerDTO.fetchRequest()
				.sort(descriptors: [.init(keyPath: \MarkerDTO.createdAt, ascending: false)])
				.fetch(predicate: predicate),
			context: SceytChatUIKit.shared.config.database.viewContext)
		{ $0.convert() }
	}()
	
	public required init(
		messageMarkerProvider: ChannelMessageMarkerProvider,
		data: MessageLayoutModel,
        queryLimit: UInt = 100,
		markerNames: [DefaultMarker]? = nil,
		localizedMarkerNames: [DefaultMarker: String]? = nil
    )
    {
		self.messageMarkerProvider = messageMarkerProvider
		self.data = data
        self.queryLimit = queryLimit
		let markerNames = markerNames ?? [DefaultMarker.displayed, DefaultMarker.received, DefaultMarker.played]
		self.localizedMarkerNames = localizedMarkerNames ?? [DefaultMarker.displayed: L10n.Message.Info.readBy,
															 DefaultMarker.received: L10n.Message.Info.deliveredTo,
															 DefaultMarker.played: L10n.Message.Info.playedBy]
		self.queries = markerNames.map {
            .Builder(messageId: data.message.id, markerName: $0.rawValue)
			.limit(queryLimit)
			.build()
		}
		super.init()
	}

    // MARK: - Data handling
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
	}

    // MARK: - Data source
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
        default: return localizedMarkerNames[DefaultMarker(rawValue: markers[section - 1].markerName)]
        }
    }
    
    open func marker(at indexPath: IndexPath) -> ChatMessage.Marker? {
        switch indexPath.section {
        case 0: nil
        default: markers[indexPath.section - 1].markerArray[indexPath.row]
        }
    }
}

public extension MessageInfoViewModel {
    enum Event {
        case reload
    }
}
