import Combine
import Foundation

import BaseFeatureInterface
import LiveStationDomainInterface

public class SignUpViewModel: ViewModel {
    public struct Input {
        let didWriteUserName: PassthroughSubject<String?, Never> = .init()
        let saveUserName: PassthroughSubject<String?, Never> = .init()
    }

    public struct Output {
        let isValid: PassthroughSubject<Bool, Never> = .init()
        let isSaved: PassthroughSubject<Bool, Never> = .init()
    }

    private let output = Output()
    private var cancellables = Set<AnyCancellable>()

    private let createChannelUsecase: any CreateChannelUsecase

    public func transform(input: Input) -> Output {
        input.didWriteUserName
            .sink { [weak self] name in
                if let isValid = self?.validate(with: name) {
                    self?.output.isValid.send(isValid)
                }
            }
            .store(in: &cancellables)

        input.saveUserName
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] name in
                self?.save(for: name)
            }
            .store(in: &cancellables)

        return output
    }

    public init(createChannelUsecase: CreateChannelUsecase) {
        self.createChannelUsecase = createChannelUsecase
    }

    private func validate(with name: String?) -> Bool {
        guard let name else { return false }
        return name.count >= 2 && name.count <= 10 && name.allSatisfy { $0.isLetter || $0.isNumber }
    }

    private func save(for name: String?) {
        guard let name else { return }
        UserDefaults.standard.set(name, forKey: "USER_NAME")

        let savedName = UserDefaults.standard.string(forKey: "USER_NAME")

        createChannelUsecase.execute(name: "Guest")
            .sink { _ in
            } receiveValue: { [weak self] channelEntity in
                UserDefaults.standard.set(channelEntity.id, forKey: "CHANNEL_ID")
                let savedID = UserDefaults.standard.string(forKey: "CHANNEL_ID")

                self?.output.isSaved.send(savedName == name && savedID != nil)
            }
            .store(in: &cancellables)
    }
}
