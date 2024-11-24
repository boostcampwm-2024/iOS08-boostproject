import Combine
import UIKit

import BaseFeatureInterface
import LiveStationDomainInterface

public struct Item: Hashable {
    let id = UUID().uuidString
    var image: UIImage?
    var title: String
    var subtitle1: String
    var subtitle2: String
    
    public init(image: UIImage? = nil, title: String, subtitle1: String, subtitle2: String) {
        self.image = image
        self.title = title
        self.subtitle1 = subtitle1
        self.subtitle2 = subtitle2
    }
}

class BroadcastFetcher: Fetcher {
    func fetch() async -> [Item] {
        return []
    }
}

public protocol Fetcher {
    func fetch() async -> [Item]
}

public class BroadcastCollectionViewModel: ViewModel {
    public struct Input {
        let fetch: PassthroughSubject<Void, Never> = .init()
        let didWriteStreamingName: PassthroughSubject<String, Never> = .init()
    }
    
    public struct Output {
        let items: PassthroughSubject<[Item], Never> = .init()
        let streamingStartButtonIsActive: PassthroughSubject<Bool, Never> = .init()
        let errorMessage: PassthroughSubject<String?, Never> = .init()
    }
    
    private let output = Output()
    private let usecase: any FetchChannelListUsecase
    private var cancellables = Set<AnyCancellable>()
    let sharedDefaults = UserDefaults(suiteName: "group.kr.codesquad.boostcamp9.Shook")!
    let isStreamingKey = "isStreaming"
    let extensionBundleID = "kr.codesquad.boostcamp9.Shook.BroadcastUploadExtension"

    
    public init(usecase: FetchChannelListUsecase) {
        self.usecase = usecase
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
            }
            .store(in: &cancellables)
        
        return output
    }
    
    private func fetchData() {

        usecase.execute()
            .sink { error in
                print(error)
            } receiveValue: { ids in
                print(ids.first?.channelId)
                self.output.items.send(ids.map { Item(title: $0.channelId, subtitle1: "test", subtitle2: "test") })
            }.store(in: &cancellables)
    }
    
    /// 방송 이름이 유효한지 확인하는 메서드
    /// - Parameter _:  방송 이름
    /// - Returns: (Bool, String?) - 유효 여부와 에러 메시지
    private func valid(_ value: String) -> (isValid: Bool, errorMessage: String?) {
        let isLengthValid = 3...20 ~= value.count
        let isCharactersValid = value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
        
        if !isLengthValid && !isCharactersValid {
            return (false, "3글자 이상,20글자 이하로 입력해 주세요. 특수문자는 언더바(_)만 가능합니다.")
        } else if !isLengthValid {
            return (false, "최소 3글자 이상, 최대 20글자 이하로 입력해 주세요.")
        } else if !isCharactersValid {
            return (false, "특수문자는 언더바(_)만 가능합니다.")
        } else {
            return (true, nil)
        }
    }
}
