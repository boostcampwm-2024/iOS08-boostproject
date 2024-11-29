import Combine
import UIKit

import BaseFeatureInterface
import BroadcastDomainInterface
import LiveStationDomainInterface

public struct Channel: Hashable {
    let id: String
    let name: String
    let thumbnailImageURLString: String
    let owner: String
    let description: String
    
    public init(id: String, title: String, imageURLString: String, owner: String = "", description: String = "") {
        self.id = id
        self.name = title
        self.thumbnailImageURLString = imageURLString
        self.owner = owner
        self.description = description
    }
}

public class BroadcastCollectionViewModel: ViewModel {
    public struct Input {
        let fetch: PassthroughSubject<Void, Never> = .init()
        let didWriteStreamingName: PassthroughSubject<String, Never> = .init()
        let didWriteStreamingDescription: PassthroughSubject<String, Never> = .init()
        let didTapBroadcastButton: PassthroughSubject<Void, Never> = .init()
        let didTapFinishStreamingButton: PassthroughSubject<Void, Never> = .init()
        let didTapStartBroadcastButton: PassthroughSubject<Void, Never> = .init()
    }
    
    public struct Output {
        let channels: PassthroughSubject<[Channel], Never> = .init()
        let streamingStartButtonIsActive: PassthroughSubject<Bool, Never> = .init()
        let errorMessage: PassthroughSubject<String?, Never> = .init()
        let showBroadcastUIView: PassthroughSubject<Void, Never> = .init()
        let dismissBroadcastUIView: PassthroughSubject<Void, Never> = .init()
        let isReadyToStream: PassthroughSubject<Bool, Never> = .init()
    }
    
    private let output = Output()
    
    private let fetchChannelListUsecase: any FetchChannelListUsecase
    private let fetchChannelInfoUsecase: any FetchChannelInfoUsecase
    private let makeBroadcastUsecase: any MakeBroadcastUsecase
    private let fetchAllBroadcastUsecase: any FetchAllBroadcastUsecase
    private let deleteBroadCastUsecase: any DeleteBroadcastUsecase
    
    private var cancellables = Set<AnyCancellable>()
    
    let sharedDefaults = UserDefaults(suiteName: "group.kr.codesquad.boostcamp9.Shook")!
    let isStreamingKey = "isStreaming"
    private let rtmp = "RTMP_SEVICE_URL"
    private let streamKey = "STREAMING_KEY"
    let extensionBundleID = "kr.codesquad.boostcamp9.Shook.BroadcastUploadExtension"
    
    private let userName = UserDefaults.standard.string(forKey: "USER_NAME") ?? ""
    private var broadcastName: String = ""
    private var channelDescription: String = ""
    private var channelID = UserDefaults.standard.string(forKey: "CHANNEL_ID")

    public init(
        fetchChannelListUsecase: FetchChannelListUsecase,
        fetchChannelInfoUsecase: FetchChannelInfoUsecase,
        makeBroadcastUsecase: MakeBroadcastUsecase,
        fetchAllBroadcastUsecase: FetchAllBroadcastUsecase,
        deleteBroadCastUsecase: DeleteBroadcastUsecase
    ) {
        self.fetchChannelListUsecase = fetchChannelListUsecase
        self.fetchChannelInfoUsecase = fetchChannelInfoUsecase
        self.makeBroadcastUsecase = makeBroadcastUsecase
        self.fetchAllBroadcastUsecase = fetchAllBroadcastUsecase
        self.deleteBroadCastUsecase = deleteBroadCastUsecase
    }
    
    public func transform(input: Input) -> Output {
        input.fetch
            .sink { [weak self] in
                self?.fetchData()
            }
            .store(in: &cancellables)
       
        input.didWriteStreamingName
            .sink { [weak self] name in
                guard let self else { return }
                let validness = valid(name)
                self.output.streamingStartButtonIsActive.send(validness.isValid)
                self.output.errorMessage.send(validness.errorMessage)
                if validness.isValid {
                    broadcastName = name
                }
            }
            .store(in: &cancellables)
        
        input.didWriteStreamingDescription
            .sink { [weak self] description in
                self?.channelDescription = description
            }
            .store(in: &cancellables)
        
        input.didTapBroadcastButton
            .sink { [weak self] _ in
                self?.output.showBroadcastUIView.send()
            }
            .store(in: &cancellables)
        
        input.didTapFinishStreamingButton
            .flatMap { [weak self] _ in
                guard let self,
                      let channelID else { return Empty<Void, Error>().eraseToAnyPublisher() }
                return deleteBroadCastUsecase.execute(id: channelID)
                    .eraseToAnyPublisher()
            }
            .sink { _ in
            } receiveValue: { [weak self] _ in
                self?.output.dismissBroadcastUIView.send()
            }
            .store(in: &cancellables)
        
        input.didTapStartBroadcastButton
            .flatMap { [weak self] in
                guard let self,
                      let channelID else { return Empty<ChannelInfoEntity, Error>().eraseToAnyPublisher() }
                output.isReadyToStream.send(false)
                return fetchChannelInfoUsecase.execute(channelID: channelID)
                    .zip(makeBroadcastUsecase.execute(id: channelID, title: broadcastName, owner: userName, description: channelDescription))
                    .map { channelInfo, _ in channelInfo }
                    .eraseToAnyPublisher()
            }
            .sink { _ in
            } receiveValue: { [weak self] channelInfo in
                guard let self else { return }
                sharedDefaults.set(channelInfo.rtmpUrl, forKey: rtmp)
                sharedDefaults.set(channelInfo.streamKey, forKey: streamKey)
                output.isReadyToStream.send(true)
            }
            .store(in: &cancellables)

        return output
    }
    
    private func fetchData() {
        fetchChannelListUsecase.execute()
            .flatMap { [weak self] channelEntities -> AnyPublisher<([ChannelEntity], [BroadcastInfoEntity]), Error> in
                guard let self else { return Empty<([ChannelEntity], [BroadcastInfoEntity]), Error>().eraseToAnyPublisher() }
                return fetchAllBroadcastUsecase.execute()
                    .map { broadcastEntities in
                        (channelEntities, broadcastEntities)
                    }
                    .eraseToAnyPublisher()
            }
            .map { channelEntities, broadcastInfoEntities -> [Channel] in
                channelEntities.map { channelEntity in
                    let broadcast = broadcastInfoEntities.first { $0.id == channelEntity.id }
                    return Channel(
                        id: channelEntity.id,
                        title: channelEntity.name,
                        imageURLString: channelEntity.imageURLString,
                        owner: broadcast?.owner ?? "Unknown",
                        description: broadcast?.description ?? ""
                    )
                }
            }
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished: break
                    case .failure(let error): print("Error: \(error)")
                    }
                },
                receiveValue: { [weak self] channels in
                    self?.output.channels.send(channels)
                }
            )
            .store(in: &cancellables)
    }

    /// 방송 이름이 유효한지 확인하는 메서드
    /// - Parameter _:  방송 이름
    /// - Returns: (Bool, String?) - 유효 여부와 에러 메시지
    private func valid(_ value: String) -> (isValid: Bool, errorMessage: String?) {
        let trimmedValue = value.trimmingCharacters(in: .whitespaces)
        
        if trimmedValue.isEmpty {
            return (false, "공백을 제외하고 최소 1글자 이상 입력해주세요.")
        } else {
            return (true, nil)
        }
    }
}
