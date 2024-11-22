import Combine
import UIKit

import BaseFeature
import DesignSystem
import EasyLayoutModule

public final class LiveStreamViewController: BaseViewController<LiveStreamViewModel> {
    private let chatingList = ChatingListView()
    private let chatInputField = ChatInputField()
    private let playerView: ShookPlayerView = ShookPlayerView(with: URL(string: "https://bitmovin-a.akamaihd.net/content/art-of-motion_drm/m3u8s/11331.m3u8")!)
    private let infoView: LiveStreamInfoView = LiveStreamInfoView()
    
    private var shrinkConstraints: [NSLayoutConstraint] = []
    private var expandConstraints: [NSLayoutConstraint] = []
    private var unfoldedConstraint: NSLayoutConstraint?
    private var foldedConstraint: NSLayoutConstraint?
    
    private var subscription = Set<AnyCancellable>()
    
    private lazy var input = LiveStreamViewModel.Input(
        expandButtonDidTap: playerView.playerControlView.expandButtonDidTap.eraseToAnyPublisher(),
        sliderValueDidChange: playerView.playerControlView.timeControlView.valueDidChanged.eraseToAnyPublisher(),
        playerStateDidChange: playerView.playerStateDidChange.eraseToAnyPublisher(),
        playerGestureDidTap: playerView.playerGestureDidTap.eraseToAnyPublisher(),
        playButtonDidTap: playerView.playerControlView.playButtonDidTap.eraseToAnyPublisher()
    )
    private lazy var output = viewModel.transform(input: input)
    
    deinit {
        print("Deinit \(Self.self)")
    }
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return output.isExpanded.value ? .landscapeLeft: .portrait
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        chatingList.isHidden = output.isExpanded.value
        chatInputField.isHidden = output.isExpanded.value
        infoView.isHidden = output.isExpanded.value
        if output.isExpanded.value {
            NSLayoutConstraint.deactivate(shrinkConstraints)
            NSLayoutConstraint.activate(expandConstraints)
        } else {
            NSLayoutConstraint.activate(shrinkConstraints)
            NSLayoutConstraint.deactivate(expandConstraints)
        }
    }
    
    public override func setupViews() {
        view.addSubview(infoView)
        view.addSubview(playerView)
        view.addSubview(chatingList)
        view.addSubview(chatInputField)
    }
    
    public override func setupStyles() {
        view.backgroundColor = .black
        
        infoView.configureUI(with: ("영상 제목이 최대 2줄까지 들어갈 예정입니다. 영상 제목이 최대 2줄까지 들어갈 예정입니다.", "닉네임•기타 정보(들어갈 수 있는 거 찾아보기)"))
    }
    
    public override func setupLayouts() {
        playerView.ezl.makeConstraint {
            $0.top(to: view.safeAreaLayoutGuide)
                .horizontal(to: view.safeAreaLayoutGuide)
        }
    
        shrinkConstraints = [playerView.heightAnchor.constraint(equalTo: playerView.widthAnchor, multiplier: 9.0 / 16.0)]
        NSLayoutConstraint.activate(shrinkConstraints)
        
        expandConstraints = [
            playerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ]
        
        unfoldedConstraint = infoView.topAnchor.constraint(equalTo: playerView.bottomAnchor)
        foldedConstraint = infoView.bottomAnchor.constraint(equalTo: playerView.bottomAnchor)
        foldedConstraint?.isActive = true
        
        infoView.ezl.makeConstraint {
            $0.horizontal(to: view)
        }
        
        chatingList.ezl.makeConstraint {
            $0.top(to: infoView.ezl.bottom)
                .horizontal(to: view)
                .bottom(to: chatInputField.ezl.top)
        }
        
        chatInputField.ezl.makeConstraint {
            $0.horizontal(to: view)
                .bottom(to: view.keyboardLayoutGuide.ezl.top)
        }
    }
        
    public override func setupActions() {
        
    }
    
    public override func setupBind() {
        output.isExpanded
            .dropFirst()
            .sink { [weak self]  flag in
            guard let self else { return }
            self.changeOrientation()
            self.playerView.playerControlView.toggleExpandButtonImage(flag)
        }
        .store(in: &subscription)
        
        output.time
            .sink { [weak self] amount in
            guard let self else { return }
            self.playerView.seek(to: amount)
        }
        .store(in: &subscription)
        
        output.isShowedPlayerControl
            .dropFirst()
            .sink { [weak self] flag in
            guard let self else { return }
            self.playerView.playerControlViewAlphaAnimalation(flag)
        }
        .store(in: &subscription)
        
        output.isShowedInfoView
            .dropFirst()
            .sink { [weak self] flag in
                guard let self else { return }
                self.infoViewConstraintAnimation(flag)
            }
            .store(in: &subscription)
        
        output.isPlaying
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] isPlaying in
                guard let self else { return }
                self.playerView.updataePlayState(isPlaying)
            }
            .store(in: &subscription)
    }
}

extension LiveStreamViewController {
    func changeOrientation() {
        let orientation: UIInterfaceOrientationMask = output.isExpanded.value ? .landscapeLeft: .portrait

        if #available(iOS 16.0, *) {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                self.setNeedsUpdateOfSupportedInterfaceOrientations()
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        } else {
            UIDevice.current.setValue(orientation, forKey: "orientation")
        }
    }
    
    private func infoViewConstraintAnimation(_ isShowed: Bool) {
        UIView.transition(with: view, duration: 0.3, options: .curveEaseInOut) {
            if isShowed {
                self.unfoldedConstraint?.isActive = true
                self.foldedConstraint?.isActive = false
            } else {
                self.unfoldedConstraint?.isActive = false
                self.foldedConstraint?.isActive = true
            }
            self.view.layoutIfNeeded()
        }
    }
}
