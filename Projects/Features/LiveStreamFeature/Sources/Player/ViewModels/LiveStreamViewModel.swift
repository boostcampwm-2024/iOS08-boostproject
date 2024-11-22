import Combine

import BaseFeatureInterface

public final class LiveStreamViewModel: ViewModel {
    
    private var subscription = Set<AnyCancellable>()
    
    public struct Input {
        let expandButtonDidTap: AnyPublisher<Void?, Never>
        let sliderValueDidChange: AnyPublisher<Float?, Never>
        let playerStateDidChange: AnyPublisher<Bool?, Never>
        let playerGestureDidTap: AnyPublisher<Void?, Never>
        let playButtonDidTap: AnyPublisher<Void?, Never>
    }
    
    public struct Output {
        let isExpanded: CurrentValueSubject<Bool, Never> = .init(false)
        let isPlaying: CurrentValueSubject<Bool, Never> = .init(false)
        let time: PassthroughSubject<Double, Never> = .init()
        let isShowedPlayerControl: CurrentValueSubject<Bool, Never> = .init(false)
        let isShowedInfoView: CurrentValueSubject<Bool, Never> = .init(false)
    }
    
    public init() {}
    
    deinit {
        print("Deinit \(Self.self)")
    }
    
    public func transform(input: Input) -> Output {
        let output = Output()
        
        input.expandButtonDidTap
            .compactMap { $0 }
            .sink {
                let nextValue = !output.isExpanded.value
                output.isExpanded.send(nextValue)
                output.isShowedPlayerControl.send(false)
                output.isShowedInfoView.send(false)
            }
            .store(in: &subscription)
        
        input.sliderValueDidChange
            .compactMap { $0 }
            .map{ Double($0) }
            .sink {
                output.time.send($0)
            }
            .store(in: &subscription)
        
        input.playerStateDidChange
            .compactMap { $0 }
            .sink { flag in
                output.isPlaying.send(flag)
            }
            .store(in: &subscription)
        
        input.playerGestureDidTap
            .compactMap { $0 }
            .sink { _ in
                output.isShowedPlayerControl.send(!output.isShowedPlayerControl.value)
                if output.isExpanded.value {
                    output.isShowedInfoView.send(false)
                } else {
                    output.isShowedInfoView.send(!output.isShowedInfoView.value)
                }
            }
            .store(in: &subscription)
                
        input.playButtonDidTap
            .compactMap { $0 }
            .sink { _ in
                output.isPlaying.send(!output.isPlaying.value)
            }
            .store(in: &subscription)
        
        return output
    }
    
}
