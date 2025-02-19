import Combine
import ReplayKit
import UIKit

import BaseFeature
import DesignSystem
import EasyLayout
import MainFeatureInterface

// MARK: - SettingUIViewController

public final class SettingUIViewController: BaseViewController<SettingViewModel> {
    deinit {
        viewModel.sharedDefaults?.removeObserver(self, forKeyPath: viewModel.isStreamingKey)
    }

    private let settingTableView = UITableView()
    private let closeBarButton = UIBarButtonItem()
    private let startBroadcastButton = UIButton()
    private let streamingDescriptionCell = SettingTableViewCell(style: .default, reuseIdentifier: nil)
    private let streamingNameCell = SettingTableViewCell(style: .default, reuseIdentifier: nil)
    private let placeholderStringOfCells = ["어떤 방송인지 알려주세요!", "방송 내용을 알려주세요!"]
    private lazy var loadingView = SHLoadingView(message: "방송 생성 중")

    private var broadcastPicker = RPSystemBroadcastPickerView()

    private let viewModelInput = SettingViewModel.Input()
    private var cancellables = Set<AnyCancellable>()

    override public func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == viewModel.isStreamingKey {
            if let newValue = change?[.newKey] as? Bool, newValue == true {
                didStartBroadCast()
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    override public func setupBind() {
        let output = viewModel.transform(input: viewModelInput)

        output.streamingStartButtonIsActive
            .sink { [weak self] isActive in
                guard let self else { return }
                startBroadcastButton.isEnabled = isActive
                startBroadcastButton.backgroundColor = isActive
                    ? DesignSystemAsset.Color.mainGreen.color
                    : DesignSystemAsset.Color.gray.color
            }
            .store(in: &cancellables)

        output.errorMessage
            .sink { [weak self] errorMessage in
                guard let self else { return }
                streamingNameCell.setErrorMessage(message: errorMessage)
            }
            .store(in: &cancellables)

        output.isReadyToStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady in
                if isReady {
                    guard let broadcastPickerButton = self?.broadcastPicker.subviews.first(where: { $0 is UIButton }) as? UIButton else { return }
                    broadcastPickerButton.sendActions(for: .touchUpInside)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } else {
                    self?.addLoadingView()
                    self?.disableButton()
                }
            }
            .store(in: &cancellables)
    }

    override public func setupViews() {
        closeBarButton.image = DesignSystemAsset.Image.xmark24.image
        closeBarButton.tintColor = .gray

        viewModel.sharedDefaults?.addObserver(self, forKeyPath: viewModel.isStreamingKey, options: [.initial, .new], context: nil)
        viewModel.sharedDefaults?.set(false, forKey: viewModel.isStreamingKey)

        navigationItem.title = "방송설정"
        navigationItem.rightBarButtonItem = closeBarButton

        settingTableView.delegate = self
        settingTableView.dataSource = self
        settingTableView.register(SettingTableViewCell.self, forCellReuseIdentifier: SettingTableViewCell.identifier)
        settingTableView.rowHeight = UITableView.automaticDimension
        settingTableView.estimatedRowHeight = 100

        broadcastPicker.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        broadcastPicker.preferredExtension = viewModel.extensionBundleID
        broadcastPicker.showsMicrophoneButton = false

        startBroadcastButton.isEnabled = false
        startBroadcastButton.addSubview(broadcastPicker)

        view.addSubview(settingTableView)
        view.addSubview(startBroadcastButton)
    }

    override public func setupStyles() {
        startBroadcastButton.setTitle("방송시작", for: .normal)
        startBroadcastButton.layer.cornerRadius = 16
        startBroadcastButton.titleLabel?.font = .setFont(.body1(weight: .semiBold))
        startBroadcastButton.backgroundColor = DesignSystemAsset.Color.gray.color
        startBroadcastButton.setTitleColor(DesignSystemAsset.Color.mainBlack.color, for: .normal)
    }

    override public func setupLayouts() {
        settingTableView.ezl.makeConstraint {
            $0.diagonal(to: view)
        }

        startBroadcastButton.ezl.makeConstraint {
            $0.height(56)
                .bottom(to: view.keyboardLayoutGuide.ezl.top, offset: -23)
                .horizontal(to: view, padding: 20)
        }

        broadcastPicker.ezl.makeConstraint {
            $0.center(to: startBroadcastButton)
                .width(startBroadcastButton.frame.width)
                .height(startBroadcastButton.frame.height)
        }
    }

    override public func setupActions() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)

        startBroadcastButton.addTarget(self, action: #selector(didTapStartBroadcastButton), for: .touchUpInside)

        closeBarButton.target = self
        closeBarButton.action = #selector(didTapRightBarButton)
    }

    /// X 모양 버튼이 눌렸을 때 호출되는 메서드
    @objc
    private func didTapRightBarButton() {
        dismiss(animated: true)
    }

    /// 방송 시작 버튼이 눌렸을 때 호출되는 메서드
    @objc
    private func didTapStartBroadcastButton() {
        viewModelInput.didTapStartBroadcastButton.send()
    }

    private func didStartBroadCast() {
        NotificationCenter.default.post(name: NotificationName.startStreaming, object: self)
        dismiss(animated: true)
    }

    @objc
    private func dismissKeyboard() {
        view.endEditing(true)
    }
}

// MARK: UITableViewDelegate, UITableViewDataSource

extension SettingUIViewController: UITableViewDelegate, UITableViewDataSource {
    public func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        placeholderStringOfCells.count
    }

    public func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            streamingNameCell.configure(
                label: "방송이름",
                placeholder: placeholderStringOfCells[indexPath.row]
            ) { [weak self] inputValue in
                self?.viewModelInput.didWriteStreamingName.send(inputValue)
            }
            return streamingNameCell
        } else {
            streamingDescriptionCell.configure(
                label: "방송정보",
                placeholder: placeholderStringOfCells[indexPath.row]
            ) { [weak self] inputValue in
                self?.viewModelInput.didWriteStreamingDescription.send(inputValue)
            }
            return streamingDescriptionCell
        }
    }

    public func tableView(_: UITableView, heightForRowAt _: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
}

extension SettingUIViewController {
    private func addLoadingView() {
        loadingView.backgroundColor = .black.withAlphaComponent(0.2)
        view.addSubview(loadingView)
        loadingView.ezl.makeConstraint {
            $0.diagonal(to: view)
        }
    }

    private func removeLoadingView() {
        loadingView.removeFromSuperview()
    }

    private func disableButton() {
        startBroadcastButton.isEnabled = false
        startBroadcastButton.backgroundColor = DesignSystemAsset.Color.gray.color
    }

    private func enableButton() {
        startBroadcastButton.isEnabled = true
        startBroadcastButton.backgroundColor = DesignSystemAsset.Color.mainGreen.color
    }
}
