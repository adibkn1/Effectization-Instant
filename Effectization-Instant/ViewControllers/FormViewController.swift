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
        
        addGradientWithBlackBackground()
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
        
        // Hide scroll indicators
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        
        // Add keyboard dismiss gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        scrollView.addGestureRecognizer(tapGesture)
        
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
        getInTouch()
        setupTextFields()
        createSubmitButton()
    }
    
    private func getInTouch() {
        label1.text = "Get in Touch"
        label1.textColor = .white
        label1.textAlignment = .left
        label1.numberOfLines = 1
        label1.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        label1.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label1)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "We'd love to hear from you"
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        subtitleLabel.font = UIFont.systemFont(ofSize: 17)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            label1.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 48),
            label1.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            subtitleLabel.topAnchor.constraint(equalTo: label1.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: label1.leadingAnchor)
        ])
    }
    
    private func setupTextFields() {
        let textFields = [nameTextField, emailTextField, companyTextField, inputTextField]
        let placeholders = ["Name", "Email", "Company", "Message"]
        
        for (index, textField) in textFields.enumerated() {
            textField.placeholder = placeholders[index]
            textField.textColor = .white
            textField.delegate = self
            textField.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(textField)
            textField.returnKeyType = .next // Change return key to next
            applyTextFieldStyles(to: textField)
        }
        
        // Set last text field's return key to done
        inputTextField.returnKeyType = .done
        
        let formStack = UIStackView(arrangedSubviews: textFields)
        formStack.axis = .vertical
        formStack.spacing = 16
        formStack.translatesAutoresizingMaskIntoConstraints = false
        formStack.setCustomSpacing(24, after: companyTextField)
        contentView.addSubview(formStack)
        
        NSLayoutConstraint.activate([
            formStack.topAnchor.constraint(equalTo: label1.bottomAnchor, constant: 48),
            formStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            formStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        
        nameTextField.heightAnchor.constraint(equalToConstant: 50).isActive = true
        emailTextField.heightAnchor.constraint(equalToConstant: 50).isActive = true
        companyTextField.heightAnchor.constraint(equalToConstant: 50).isActive = true
        inputTextField.heightAnchor.constraint(equalToConstant: 120).isActive = true
    }
    
    
    private func createSubmitButton() {
        submitButton = UIButton(type: .system)
        submitButton.setTitle("Submit", for: .normal)
        submitButton.setTitleColor(.black, for: .normal)
        submitButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        submitButton.backgroundColor = .white
        submitButton.layer.cornerRadius = 25
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        
        submitButton.layer.shadowColor = UIColor.white.withAlphaComponent(0.5).cgColor
        submitButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        submitButton.layer.shadowRadius = 4
        submitButton.layer.shadowOpacity = 0.1
        
        contentView.addSubview(submitButton)
        
        submitButton.addTarget(self, action: #selector(submitButtonTapped), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            submitButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            submitButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            submitButton.topAnchor.constraint(equalTo: inputTextField.bottomAnchor, constant: 32),
            submitButton.heightAnchor.constraint(equalToConstant: 50),
        ])
        
        submitButtonBottomConstraint = submitButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        submitButtonBottomConstraint?.isActive = true
    }
    
    private func addGradientWithBlackBackground() {
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
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
        
        // Find the active text field
        let activeTextField: UITextField? = [nameTextField, emailTextField, companyTextField, inputTextField].first { $0.isFirstResponder }
        
        guard let activeField = activeTextField else { return }
        
        let bottomOfTextField = activeField.convert(activeField.bounds, to: scrollView).maxY
        let topOfKeyboard = scrollView.frame.height - keyboardSize.height
        
        // Calculate the offset needed to show the active text field
        let offset = bottomOfTextField - topOfKeyboard + 20 // 20 points of padding
        
        if offset > 0 {
            scrollView.setContentOffset(CGPoint(x: 0, y: offset), animated: true)
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.setContentOffset(.zero, animated: true)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case nameTextField:
            emailTextField.becomeFirstResponder()
        case emailTextField:
            companyTextField.becomeFirstResponder()
        case companyTextField:
            inputTextField.becomeFirstResponder()
        case inputTextField:
            textField.resignFirstResponder()
        default:
            textField.resignFirstResponder()
        }
        return true
    }
    
    private func applyTextFieldStyles(to textField: UITextField) {
        textField.textColor = .white
        textField.font = UIFont.systemFont(ofSize: 17)
        textField.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        textField.layer.cornerRadius = 12
        textField.clipsToBounds = true
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.leftViewMode = .always
        textField.borderStyle = .none
        
        textField.attributedPlaceholder = NSAttributedString(
            string: textField.placeholder ?? "",
            attributes: [
                NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.4),
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17)
            ]
        )
        
        if textField == emailTextField {
            textField.keyboardType = .emailAddress
            textField.autocapitalizationType = .none
        }
        
        if textField == inputTextField {
            textField.placeholder = "Write your message here..."
        }
    }
}
