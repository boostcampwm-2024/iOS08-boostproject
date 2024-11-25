import Combine
import UIKit

import BaseFeatureInterface
import LiveStationDomainInterface

public struct Channel: Hashable {
    let id = UUID().uuidString
    var name: String
    var image: UIImage?
    
    public init(title: String, image: UIImage? = nil) {
        self.image = image
        self.name = title
    }
}

public class BroadcastCollectionViewModel: ViewModel {
    public struct Input {
        let fetch: PassthroughSubject<Void, Never> = .init()
        let didWriteStreamingName: PassthroughSubject<String, Never> = .init()
    }
    
    public struct Output {
        let channels: PassthroughSubject<[Channel], Never> = .init()
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
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { entity in
                    self.output.channels.send(entity.map {
                        Channel(title: $0.name, image: $0.image)
                    })
                }
            )
            .store(in: &cancellables)
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
