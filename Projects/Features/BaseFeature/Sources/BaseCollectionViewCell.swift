import UIKit

import BaseFeatureInterface

open class BaseCollectionViewCell: UICollectionViewCell, ViewLifeCycle {
    public static var identifier: String {
        String(describing: Self.self)
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupStyles()
        setupLayouts()
        setupActions()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupStyles()
        setupLayouts()
        setupActions()
    }

    // MARK: - View Life Cycle

    open func setupViews() {}

    open func setupStyles() {}

    open func updateStyles() {}

    open func setupLayouts() {}

    open func updateLayouts() {}

    open func setupActions() {}
}
