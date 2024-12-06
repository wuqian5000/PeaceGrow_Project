import SwiftUI

struct RegistrationView: View {
    @State private var email = ""
    @State private var fullname = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: AuthViewModel

    var body: some View {
        VStack {
            Image("BrightLightLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 120)
                .padding(.vertical, 32)
                .background(Color.clear)
            
            VStack(spacing: 24) {
                InputView(text: $email,
                          title: "Email Address",
                          placeholder: "name@example.com")
                .autocapitalization(.none)

                InputView(text: $fullname,
                          title: "Full Name",
                          placeholder: "Enter your name")

                InputView(text: $password,
                          title: "Password",
                          placeholder: "Enter your password",
                          isSecureField: true)

                ZStack(alignment: .trailing){
                    InputView(text: $confirmPassword,
                              title: "Confirm Password",
                              placeholder: "Confirm your password",
                              isSecureField: true)
                    
                    if !password.isEmpty && !confirmPassword.isEmpty {
                        if password == confirmPassword {
                            Image(systemName: "checkmark.circle.fill")
                                .imageScale(.large)
                                .fontWeight(.bold)
                                .foregroundColor(Color(.systemGreen))
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .imageScale(.large)
                                .fontWeight(.bold)
                                .foregroundColor(Color(.systemRed))
                        }
                    }

                }
                
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            Button {
                Task {
                    do {
                        try await viewModel.createUser(withEmail: email, password: password, fullname: fullname)
                        print("Attempting to create user with email: \(email), password: \(password), fullname: \(fullname)")
                    } catch {
                        print("Error during signup: \(error)")
                    }
                }
            } label: {
                HStack {
                    Text("SIGN UP")
                        .fontWeight(.semibold)
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .frame(width: UIScreen.main.bounds.width - 32, height: 48)
                .background(Color(.systemBlue))
                .disabled(!formIsValid)
                .opacity(formIsValid ? 1.0 : 0.5)
                .cornerRadius(10)
                .padding(.top, 24)
            }

            Spacer()
            
            Button {
                dismiss()
            } label: {
                HStack(spacing: 3) {
                    Text("Already have an account?")
                    Text("Sign in")
                        .fontWeight(.bold)
                }
                .font(.system(size: 14))
            }
        }
        .onAppear {
            print("RegistrationView appeared")
            print("Button dimensions: width = \(UIScreen.main.bounds.width - 32), height = 48")
            print("Logo dimensions: width = 100, height = 120")
        }
    }
}


// authentication protocal

extension RegistrationView: AuthenticationFormProtocol {
    var formIsValid: Bool {
        return !email.isEmpty
        && email.contains("@")
        && !password.isEmpty
        && password.count > 5
        && password == confirmPassword
        && !fullname.isEmpty
    }
}

struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        RegistrationView()
            .environmentObject(AuthViewModel())
    }
}
