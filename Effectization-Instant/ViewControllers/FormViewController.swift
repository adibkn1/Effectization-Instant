//
//  SettingsViewController.swift
//  QR Scanner
//
//  Created by Swarup Panda on 04/10/24.
//

import UIKit

class FormViewController: UIViewController, UITextFieldDelegate {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let companyName = UILabel()
    
    private let logoImageView = UIImageView()
    private let label1 = UILabel()
    private var submitButton: UIButton!
    
    private let nameTextField = UITextField()
    private let emailTextField = UITextField()
    private let companyTextField = UITextField()
    private let inputTextField = UITextField()
    
    private var submitButtonBottomConstraint: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black
        setupScrollView()
        setupUI()
        setupGesturesAndObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    
    private func setupUI() {
        companyLogo()
        companyLabel()
        getInTouch()
        setupTextFields()
        createSubmitButton()
    }
    
    private func companyLogo() {
        logoImageView.image = UIImage(named: "companylogo")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(logoImageView)
        
        NSLayoutConstraint.activate([
            logoImageView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 20),
            logoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            logoImageView.heightAnchor.constraint(equalToConstant: 65),
            logoImageView.widthAnchor.constraint(equalToConstant: 65)
        ])
    }
    
    private func companyLabel() {
        let text = "Effectization\nStudio"
        let attributedText = NSMutableAttributedString(string: text)
        let lightYellow = UIColor(red: 1.0, green: 1.0, blue: 0.5, alpha: 1.0)
        
        attributedText.addAttribute(.foregroundColor, value: lightYellow, range: (text as NSString).range(of: "Effectization"))
        attributedText.addAttribute(.foregroundColor, value: UIColor.white, range: (text as NSString).range(of: "Studio"))
        
        companyName.attributedText = attributedText
        companyName.textAlignment = .left
        companyName.numberOfLines = 2
        companyName.font = UIFont.boldSystemFont(ofSize: 28)
        companyName.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(companyName)
        
        NSLayoutConstraint.activate([
            companyName.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 80),
            companyName.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 20),
        ])
    }
    
    private func getInTouch() {
        label1.text = "GET IN TOUCH"
        label1.textColor = .white
        label1.textAlignment = .left
        label1.numberOfLines = 2
        label1.font = UIFont.systemFont(ofSize: 24, weight: .heavy)
        label1.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label1)
        
        NSLayoutConstraint.activate([
            label1.topAnchor.constraint(equalTo: companyName.bottomAnchor, constant: 50),
            label1.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
        ])
    }
    
    private func setupTextFields() {
        let textFields = [nameTextField, emailTextField, companyTextField, inputTextField]
        let placeholders = ["Name", "Email", "Company", "Message"]
        let placeholderAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.gray
        ]
        
        for (index, textField) in textFields.enumerated() {
            textField.placeholder = placeholders[index]
            textField.attributedPlaceholder = NSAttributedString(string: textField.placeholder ?? "", attributes: placeholderAttributes)
            textField.borderStyle = .roundedRect
            textField.backgroundColor = UIColor(red: 35/255, green: 45/255, blue: 60/255, alpha: 1.0)
            textField.textColor = .white
            textField.delegate = self
            textField.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(textField)
            
            textField.returnKeyType = .done
        }
        
        emailTextField.keyboardType = .emailAddress
        
        let stackView = UIStackView(arrangedSubviews: textFields)
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: label1.bottomAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
        
        nameTextField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        emailTextField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        companyTextField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        inputTextField.heightAnchor.constraint(equalToConstant: 88).isActive = true
    }
    
    
    private func createSubmitButton() {
        submitButton = UIButton(type: .system)
        submitButton.setTitle("Submit", for: .normal)
        submitButton.setTitleColor(.black, for: .normal)
        submitButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        submitButton.layer.borderWidth = 1.0
        submitButton.layer.borderColor = UIColor.clear.cgColor
        submitButton.layer.cornerRadius = 25
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(submitButton)
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemYellow.cgColor,
            UIColor(red: 1.0, green: 1.0, blue: 0.5, alpha: 1.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 120, height: 50)
        gradientLayer.cornerRadius = 25
        
        submitButton.layer.insertSublayer(gradientLayer, at: 0)
        
        submitButton.addTarget(self, action: #selector(submitButtonTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            submitButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            submitButton.topAnchor.constraint(equalTo: inputTextField.bottomAnchor, constant: 30),
            submitButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),
            submitButton.heightAnchor.constraint(equalToConstant: 50),
        ])
        
        submitButtonBottomConstraint = submitButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        submitButtonBottomConstraint?.isActive = true
        
        submitButton.layoutIfNeeded()
        gradientLayer.frame = submitButton.bounds
    }
    
    
    @objc private func submitButtonTapped() {
        submitForm()
    }
    
    private func submitForm() {
        guard let name = nameTextField.text, !name.isEmpty,
              let email = emailTextField.text, !email.isEmpty,
              let company = companyTextField.text, !company.isEmpty,
              let input = inputTextField.text, !input.isEmpty else {
            showAlert(title: "Error", message: "Please fill all fields")
            return
        }
        
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        guard emailPred.evaluate(with: email) else {
            showAlert(title: "Error", message: "Please enter a valid email address")
            return
        }
        
        let url = URL(string: "https://docs.google.com/forms/u/0/d/e/1FAIpQLScUguD2__4okFoAmjcLWus8Q9hmB8gHkl4qlgEhQxzKljm-Fg/formResponse")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let postString = "entry.485428648=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&entry.879531967=\(email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&entry.326955045=\(company.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&entry.267295726=\(input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        request.httpBody = postString.data(using: .utf8)
        
        submitButton.isEnabled = false
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.submitButton.isEnabled = true
                
                if let error = error {
                    self?.showAlert(title: "Error", message: "Failed to submit form: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    self?.showAlert(title: "Error", message: "Failed to submit form. Please try again later.")
                    return
                }
                
                self?.showAlert(title: "Success", message: "Form submitted successfully") {
                    self?.clearFormFields()
                }
            }
        }
        task.resume()
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completion?() })
        present(alert, animated: true, completion: nil)
    }
    
    private func clearFormFields() {
        nameTextField.text = ""
        emailTextField.text = ""
        companyTextField.text = ""
        inputTextField.text = ""
    }
    
    private func setupGesturesAndObservers() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        
        let keyboardHeight = keyboardSize.height
        let bottomPadding = view.safeAreaInsets.bottom
        
        submitButtonBottomConstraint?.constant = -keyboardHeight - 20 + bottomPadding
        
        let submitButtonBottom = submitButton.frame.origin.y + submitButton.frame.size.height + 20 // 20 is the bottom margin
        let newContentOffset = CGPoint(x: 0, y: max(submitButtonBottom - scrollView.frame.size.height + keyboardHeight, 0))
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
            self.scrollView.setContentOffset(newContentOffset, animated: false)
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        submitButtonBottomConstraint?.constant = -20
        
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
