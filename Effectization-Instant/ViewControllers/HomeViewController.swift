//
//  HomeViewController.swift
//  QR Scanner
//
//  Created by Swarup Panda on 04/10/24.
//

import UIKit

class HomeViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    private let contentProvider: ContentProvider
    
    init(contentProvider: ContentProvider = DefaultContentProvider()) {
        self.contentProvider = contentProvider
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.contentProvider = DefaultContentProvider()
        super.init(coder: coder)
    }
    
    private var buttonTitles: [String] {
        return contentProvider.getAllCategories()
    }
    
    let scrollView = UIScrollView()
    let contentView = UIView()
    
    let companyName = UILabel()
    let qrButton = UIButton()
    
    private var collectionView: UICollectionView!
    private var selectedIndex: IndexPath?
    
    private let imageCache = NSCache<NSString, UIImage>()
    
    private var imageContainerView: UIView!
    private var imageViews: [UIImageView] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = .black
        
        setupScrollView()
        setupContentView()
        setupCompanyLabel()
        setupQRScannerButton()
        setupHorizontalScrollView()
        setupImageViews()
        
        let defaultIndex = IndexPath(item: 0, section: 0)
        selectedIndex = defaultIndex
        collectionView.selectItem(at: defaultIndex, animated: false, scrollPosition: .centeredHorizontally)
        collectionView.reloadData()
    }
    
    func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func setupContentView() {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func setupCompanyLabel() {
        let text = "Effectization\nStudio"
        let attributedText = NSMutableAttributedString(string: text)
        let lightYellow = UIColor(red: 1.0, green: 1.0, blue: 0.5, alpha: 1.0)
        
        attributedText.addAttribute(.foregroundColor, value: lightYellow, range: (text as NSString).range(of: "Effectization"))
        attributedText.addAttribute(.foregroundColor, value: UIColor.white, range: (text as NSString).range(of: "Studio"))
        
        companyName.attributedText = attributedText
        companyName.textAlignment = .left
        companyName.numberOfLines = 2
        companyName.font = UIFont.boldSystemFont(ofSize: 36)
        companyName.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(companyName)
        
        NSLayoutConstraint.activate([
            companyName.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 50),
            companyName.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
        ])
    }
    
    private func setupQRScannerButton() {
        qrButton.setImage(UIImage(systemName: "qrcode.viewfinder"), for: .normal)
        qrButton.tintColor = .white
        qrButton.backgroundColor = UIColor(red: 35/255, green: 45/255, blue: 60/255, alpha: 1.0)
        qrButton.layer.cornerRadius = 25
        qrButton.clipsToBounds = true
        qrButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(qrButton)
        
        NSLayoutConstraint.activate([
            qrButton.widthAnchor.constraint(equalToConstant: 50),
            qrButton.heightAnchor.constraint(equalToConstant: 50),
            qrButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 60),
            qrButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30)
        ])
        
        qrButton.addTarget(self, action: #selector(didTapQRScanner), for: .touchUpInside)
    }
    
    @objc private func didTapQRScanner() {
        let qrViewController = QRViewController()
        qrViewController.modalPresentationStyle = .fullScreen
        present(qrViewController, animated: true, completion: nil)
    }
    
    private func setupHorizontalScrollView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        collectionView.register(HorizontalButtonCell.self, forCellWithReuseIdentifier: "HorizontalButtonCell")
        
        contentView.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: companyName.bottomAnchor, constant: 20),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupImageViews() {
        imageContainerView = UIView()
        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageContainerView)
        
        NSLayoutConstraint.activate([
            imageContainerView.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 20),
            imageContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
        
        updateImageViews(for: "AR")
    }
    
    private func updateImageViews(for category: String) {
        imageContainerView.subviews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()
        
        guard let contents = ContentConfiguration.contentForButtons[category] else { return }
        
        var lastAnchor: NSLayoutYAxisAnchor? = imageContainerView.topAnchor
        
        for content in contents {
            let imageView = addImageView(with: content, below: lastAnchor, in: imageContainerView)
            imageViews.append(imageView)
            lastAnchor = imageView.bottomAnchor
        }
        
        if let lastAnchor = lastAnchor {
            imageContainerView.bottomAnchor.constraint(equalTo: lastAnchor, constant: 20).isActive = true
            contentView.bottomAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: 20).isActive = true
        }
    }
    
    private func addImageView(with content: ImageViewContent, below anchor: NSLayoutYAxisAnchor?, in containerView: UIView) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 30
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "photo.fill")
        imageView.tintColor = .gray
        
        let infoButton = UIButton(type: .system)
        infoButton.setImage(UIImage(systemName: "chevron.forward"), for: .normal)
        infoButton.tintColor = .black
        infoButton.backgroundColor = UIColor(red: 1.0, green: 1.0, blue: 0.5, alpha: 1)
        infoButton.layer.cornerRadius = 30
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        infoButton.accessibilityLabel = "Open more options"
        
        let urlKey = UnsafeRawPointer(bitPattern: "linkUrl".hashValue)!
        infoButton.setAssociatedObject(content.linkUrl, forKey: urlKey)
        infoButton.addTarget(self, action: #selector(openWikipediaLink(_:)), for: .touchUpInside)
        
        let imageTitle = UILabel()
        imageTitle.text = content.topTitle
        imageTitle.textColor = UIColor(red: 1.0, green: 1.0, blue: 0.5, alpha: 1)
        imageTitle.textAlignment = .center
        imageTitle.numberOfLines = 2
        imageTitle.font = UIFont.systemFont(ofSize: 19, weight: .semibold)
        imageTitle.translatesAutoresizingMaskIntoConstraints = false
        imageTitle.adjustsFontForContentSizeCategory = true
        imageTitle.accessibilityLabel = content.topTitle
        
        let blurredView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blurredView.translatesAutoresizingMaskIntoConstraints = false
        blurredView.backgroundColor = UIColor(white: 0.5, alpha: 0.01)
        blurredView.layer.cornerRadius = 25
        blurredView.clipsToBounds = true
        
        blurredView.layer.shadowColor = UIColor.black.cgColor
        blurredView.layer.shadowOpacity = 0.3
        blurredView.layer.shadowOffset = CGSize(width: 0, height: 5)
        blurredView.layer.shadowRadius = 10
        
        let overlayView = UIView()
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.backgroundColor = UIColor(white: 15, alpha: 0.01)
        overlayView.layer.cornerRadius = 25
        overlayView.clipsToBounds = true
        
        blurredView.contentView.addSubview(overlayView)
        
        containerView.addSubview(imageView)
        containerView.addSubview(infoButton)
        blurredView.contentView.addSubview(imageTitle)
        containerView.addSubview(blurredView)
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -15),
            imageView.heightAnchor.constraint(equalToConstant: 500),
            imageView.topAnchor.constraint(equalTo: anchor ?? containerView.topAnchor, constant: 20),
            
            infoButton.widthAnchor.constraint(equalToConstant: 60),
            infoButton.heightAnchor.constraint(equalToConstant: 60),
            infoButton.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -20),
            infoButton.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -20),
            
            blurredView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -25),
            blurredView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 20),
            blurredView.trailingAnchor.constraint(lessThanOrEqualTo: imageView.trailingAnchor, constant: -20),
            blurredView.heightAnchor.constraint(greaterThanOrEqualToConstant: 55),
            
            imageTitle.topAnchor.constraint(equalTo: blurredView.contentView.topAnchor, constant: 8),
            imageTitle.bottomAnchor.constraint(equalTo: blurredView.contentView.bottomAnchor, constant: -8),
            imageTitle.leadingAnchor.constraint(equalTo: blurredView.contentView.leadingAnchor, constant: 18),
            imageTitle.trailingAnchor.constraint(equalTo: blurredView.contentView.trailingAnchor, constant: -18),
            
            overlayView.topAnchor.constraint(equalTo: blurredView.contentView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: blurredView.contentView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: blurredView.contentView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: blurredView.contentView.bottomAnchor)
        ])

        
        if let cachedImage = imageCache.object(forKey: content.imageUrl as NSString) {
            DispatchQueue.main.async {
                imageView.image = cachedImage
            }
            return imageView
        }
        
        guard let url = URL(string: content.imageUrl) else { return imageView }
        
        URLSession.shared.dataTask(with: url) { [weak self] (data, _, error) in
            if let error = error {
                print("Image download error: \(error.localizedDescription)")
                return
            }
            guard let data = data, let image = UIImage(data: data) else {
                print("Invalid image data")
                return
            }
            self?.imageCache.setObject(image, forKey: content.imageUrl as NSString)
            DispatchQueue.main.async {
                imageView.image = image
            }
        }.resume()
        
        return imageView
    }
    
    
    @objc private func openWikipediaLink(_ sender: UIButton) {
        let key = UnsafeRawPointer(bitPattern: "linkUrl".hashValue)!
        guard let urlString = sender.getAssociatedObject(forKey: key) as? String,
              let url = URL(string: urlString) else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return buttonTitles.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HorizontalButtonCell", for: indexPath) as! HorizontalButtonCell
        cell.configure(with: buttonTitles[indexPath.item], isSelected: indexPath == selectedIndex)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let widestWidth = buttonTitles.map { title in
            title.size(withAttributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)]).width + 32
        }.max() ?? 100
        
        return CGSize(width: widestWidth, height: 45)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if selectedIndex != indexPath {
            selectedIndex = indexPath
            let selectedCategory = buttonTitles[indexPath.item]
            
            UIView.transition(with: imageContainerView,
                              duration: 0.5,
                              options: .transitionCrossDissolve,
                              animations: {
                self.imageViews.forEach { $0.removeFromSuperview() }
                self.imageViews.removeAll()
                
                self.updateImageViews(for: selectedCategory)
            }, completion: nil)
            
            collectionView.reloadData()
        }
        print("\(buttonTitles[indexPath.item]) tapped")
    }
}

extension UIButton {
    private struct AssociatedKeys {
        static var linkUrlKey = "linkUrlKey"
    }
    
    func setAssociatedObject(_ object: Any, forKey key: UnsafeRawPointer) {
        objc_setAssociatedObject(self, key, object, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    func getAssociatedObject(forKey key: UnsafeRawPointer) -> Any? {
        return objc_getAssociatedObject(self, key)
    }
}
