import AVFoundation
import BaseFeature
import DesignSystem
import EasyLayoutModule
import UIKit

final class ShookPlayerView: BaseView {
    
    private var playerItem: AVPlayerItem
    
    private let player: AVPlayer = AVPlayer()
    
    private lazy var playerLayer: AVPlayerLayer = {
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    
    private let playButton: UIButton = UIButton()
    
    private lazy var videoContainerView: UIView = {
        let view = UIView()
        view.layer.addSublayer(playerLayer)
        return view
    }()
    
    private let indicatorView: UIActivityIndicatorView =  UIActivityIndicatorView()
    
    init(with url: URL) {
        playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.play()
        super.init(frame: .zero)
        addObserver()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.removeObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus))
        self.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        self.removeObserver(self, forKeyPath: BufferState.playbackBufferEmpty.rawValue)
        self.removeObserver(self, forKeyPath: BufferState.playbackLikelyToKeepUp.rawValue)
        self.removeObserver(self, forKeyPath: BufferState.playbackBufferFull.rawValue)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        guard let keyPath = keyPath else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if let playerItem = object as? AVPlayerItem {
            
            switch playerItem.status {
            case .readyToPlay: // 성공
                print("재생 준비 완료")
            case.failed:
                print("실패")
            case .unknown:
                print("아직 실패")
            @unknown default:
                fatalError()
            }
            
            switch keyPath {
            case "playbackBufferEmpty":
                indicatorView.startAnimating()
            case "playbackLikelyToKeepUp", "playbackBufferFull":
                indicatorView.stopAnimating()
            default:
                return
            }
            
        } else if let player = object as? AVPlayer  {
            switch player.timeControlStatus {
            case .playing:
                playButton.configuration?.image = DesignSystemAsset.Image.pause48.image
                print("재생 시작")
            case.paused:
                playButton.configuration?.image = DesignSystemAsset.Image.play48.image
            case .waitingToPlayAtSpecifiedRate:
                print("재생 대기")
            @unknown default:
                fatalError()
            }
        }
    }
    
    override func setupViews() {
        super.setupViews()
        self.addSubview(videoContainerView)
        videoContainerView.addSubview(playButton)
        videoContainerView.addSubview(indicatorView)
    }
    
    override func setupLayouts() {
        super.setupLayouts()
        
        videoContainerView.ezl.makeConstraint {
            $0.diagonal(to: self)
        }
        
        playButton.ezl.makeConstraint {
            $0.center(to: videoContainerView)
        }
        
        indicatorView.ezl.makeConstraint {
            $0.width(30).height(30).center(to: videoContainerView)
        }
    }
    
    override func setupStyles() {
        playerLayer.frame = videoContainerView.bounds
        
        var playButtonConfig = UIButton.Configuration.plain()
        playButtonConfig.image = DesignSystemAsset.Image.play48.image
        playButton.configuration = playButtonConfig
        
        indicatorView.color = DesignSystemAsset.Color.mainGreen.color
        indicatorView.hidesWhenStopped = true 
    }
    
    override func setupActions() {
        playButton.addAction(UIAction(handler: { [weak self] _ in
            guard let self else { return }
            self.player.pause()
        }), for: .touchUpInside)
    }
    
}

extension ShookPlayerView {
    
    enum BufferState: String {
        case playbackBufferEmpty
        case playbackLikelyToKeepUp
        case playbackBufferFull
    }
    
    private func addObserver() {
        addObserverPlayerItem()
         addObserverPlayer()
    }
    
    private func addObserverPlayerItem() {
        playerItem.addObserver(self,
                               forKeyPath: #keyPath(AVPlayerItem.status),
                               options: [.old, .new],
                               context: nil) // 동일한 객체를 여러 키 경로에서 관찰할 때 구분하기 위한 식별자
        
        playerItem.addObserver(self, forKeyPath: BufferState.playbackBufferEmpty.rawValue, options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: BufferState.playbackLikelyToKeepUp.rawValue, options: .new, context: nil)
        playerItem.addObserver(self, forKeyPath: BufferState.playbackBufferFull.rawValue, options: .new, context: nil)
    }
    
    private func addObserverPlayer() {
        player.addObserver(self, forKeyPath: "timeControlStatus", context: nil)
    }
    
}
