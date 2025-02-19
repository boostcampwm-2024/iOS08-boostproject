import Combine
import Foundation

import BroadcastDomainInterface

public struct FetchAllBroadcastUsecaseImpl: FetchAllBroadcastUsecase {
    private let repository: any BroadcastRepository

    public init(repository: any BroadcastRepository) {
        self.repository = repository
    }

    public func execute() -> AnyPublisher<[BroadcastInfoEntity], any Error> {
        repository.fetchAllBroadcast()
    }
}
