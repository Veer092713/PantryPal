import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var email           = ""
    @State private var password        = ""
    @State private var confirmPassword = ""
    @State private var nickname        = ""
    @State private var isCreatingAccount  = false
    @State private var showPassword       = false
    @State private var appeared           = false
    @State private var showForgotPassword = false

    enum Field { case email, nickname, password, confirmPassword }
    @FocusState private var focus: Field?

    private func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    private var canProceed: Bool {
        let e = email.trimmingCharacters(in: .whitespaces)
        let n = nickname.trimmingCharacters(in: .whitespaces)
        if isCreatingAccount {
            return isValidEmail(e) && !n.isEmpty && password.count >= 6 && password == confirmPassword
        }
        return isValidEmail(e) && !password.isEmpty
    }

    var body: some View {
        ZStack {
            // ── Background ────────────────────────────────────────────
            LinearGradient(
                colors: [
                    Color(red: 0.00, green: 0.25, blue: 0.31),
                    Color(red: 0.00, green: 0.46, blue: 0.54)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Decorative ambient circles
            Circle()
                .fill(.white.opacity(0.055))
                .frame(width: 440, height: 440)
                .offset(x: 170, y: -200)
                .blur(radius: 3)
            Circle()
                .fill(.white.opacity(0.040))
                .frame(width: 340, height: 340)
                .offset(x: -150, y: 270)
                .blur(radius: 3)

            VStack(spacing: 0) {

                Spacer()

                // ── Logo + headline ───────────────────────────────────
                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.08))
                            .frame(width: 158, height: 158)
                        Circle()
                            .fill(.white.opacity(0.05))
                            .frame(width: 186, height: 186)
                        HStack(alignment: .lastTextBaseline, spacing: 1) {
                            Text("P")
                                .font(.system(size: 54, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("antry")
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                            Text("P")
                                .font(.system(size: 54, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.leading, 4)
                            Text("al")
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .shadow(color: .black.opacity(0.22), radius: 28, y: 14)
                    .scaleEffect(appeared ? 1 : 0.72)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.62, dampingFraction: 0.70), value: appeared)

                    VStack(spacing: 9) {
                        Text("PantryPal")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Track expiry dates, reduce waste,\nand stay organised.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 14)
                    .animation(.spring(response: 0.62, dampingFraction: 0.80).delay(0.10), value: appeared)
                }

                Spacer()

                // ── Glass card ────────────────────────────────────────
                VStack(spacing: 20) {

                    // Heading
                    VStack(alignment: .leading, spacing: 5) {
                        Text(isCreatingAccount ? "Create Account" : "Welcome Back")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                        Text(isCreatingAccount
                             ? "Sign up to sync your data across devices"
                             : "Sign in to access your products")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeInOut(duration: 0.2), value: isCreatingAccount)

                    // ── Fields ────────────────────────────────────────
                    VStack(spacing: 12) {

                        // Email
                        inputRow(icon: "envelope.fill", field: .email) {
                            TextField("Email", text: $email)
                                .focused($focus, equals: .email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .onSubmit { focus = .password }
                        }

                        // Nickname (create account only)
                        if isCreatingAccount {
                            inputRow(icon: "person.fill", field: .nickname) {
                                TextField("Preferred nickname", text: $nickname)
                                    .focused($focus, equals: .nickname)
                                    .textInputAutocapitalization(.words)
                                    .autocorrectionDisabled()
                                    .submitLabel(.next)
                                    .onSubmit { focus = .password }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Password
                        inputRow(icon: "lock.fill", field: .password) {
                            Group {
                                if showPassword {
                                    TextField("Password", text: $password)
                                } else {
                                    SecureField("Password", text: $password)
                                }
                            }
                            .focused($focus, equals: .password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(isCreatingAccount ? .next : .go)
                            .onSubmit {
                                if isCreatingAccount { focus = .confirmPassword }
                                else if canProceed { submit() }
                            }

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                            }
                        }

                        // Confirm Password (create account only)
                        if isCreatingAccount {
                            inputRow(icon: "lock.shield.fill", field: .confirmPassword) {
                                SecureField("Confirm Password", text: $confirmPassword)
                                    .focused($focus, equals: .confirmPassword)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .submitLabel(.go)
                                    .onSubmit { if canProceed { submit() } }

                                if !confirmPassword.isEmpty {
                                    Image(systemName: confirmPassword == password
                                          ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(confirmPassword == password ? .green : .red)
                                }
                            }
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isCreatingAccount)

                    // ── Forgot Password ───────────────────────────────
                    if !isCreatingAccount {
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                showForgotPassword = true
                            }
                            .font(.footnote)
                            .foregroundStyle(.teal)
                        }
                        .transition(.opacity)
                    }

                    // ── Error message ─────────────────────────────────
                    if let error = auth.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                    }

                    // ── CTA button ────────────────────────────────────
                    Button(action: submit) {
                        HStack(spacing: 10) {
                            if auth.isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            } else {
                                Text(isCreatingAccount ? "Create Account" : "Sign In")
                                    .font(.headline)
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.title3)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            canProceed
                                ? AnyShapeStyle(Color.teal.gradient)
                                : AnyShapeStyle(Color.secondary.opacity(0.22)),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .disabled(!canProceed || auth.isLoading)
                    .animation(.easeInOut(duration: 0.18), value: canProceed)

                    // ── Toggle sign in / create account ───────────────
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isCreatingAccount.toggle()
                            auth.errorMessage = nil
                            confirmPassword     = ""
                            nickname            = ""
                        }
                    } label: {
                        Text(isCreatingAccount
                             ? "Already have an account? **Sign In**"
                             : "No account yet? **Create one**")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
                .padding(28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 52)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 44)
                .animation(.spring(response: 0.66, dampingFraction: 0.82).delay(0.18), value: appeared)
            }
        }
        .onAppear {
            guard !appeared else { return }
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focus = .email }
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet(prefillEmail: email.trimmingCharacters(in: .whitespaces))
                .environmentObject(auth)
        }
    }

    // MARK: - Input Row Builder

    @ViewBuilder
    private func inputRow<Content: View>(
        icon: String,
        field: Field,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.teal)
                .frame(width: 20)
            content()
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(focus == field ? Color.teal : Color.clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.16), value: focus)
    }

    // MARK: - Submit (main form)

    private func submit() {
        let e = email.trimmingCharacters(in: .whitespaces)
        let n = nickname.trimmingCharacters(in: .whitespaces)
        guard !e.isEmpty else { return }
        Task {
            if isCreatingAccount {
                await auth.signUp(email: e, password: password, nickname: n)
            } else {
                await auth.signIn(email: e, password: password)
            }
        }
    }
}

// MARK: - Forgot Password Sheet

struct ForgotPasswordSheet: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss

    let prefillEmail: String

    @State private var email    = ""
    @State private var sent     = false
    @FocusState private var focused: Bool

    private func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: sent ? "checkmark.circle.fill" : "lock.rotation")
                        .font(.system(size: 36))
                        .foregroundStyle(.teal)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: sent)

                VStack(spacing: 8) {
                    Text(sent ? "Check Your Email" : "Forgot Password?")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(sent
                         ? "A password reset link has been sent to\n\(email). Tap it to set a new password."
                         : "Enter your email and we'll send you a link to reset your password.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                if !sent {
                    // Email field
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.teal)
                            .frame(width: 20)
                        TextField("Email", text: $email)
                            .focused($focused)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.send)
                            .onSubmit { sendReset() }
                    }
                    .padding()
                    .background(Color(.systemGray6),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(focused ? Color.teal : Color.clear, lineWidth: 1.5)
                    )
                    .animation(.easeInOut(duration: 0.16), value: focused)

                    // Error
                    if let error = auth.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Send button
                    Button(action: sendReset) {
                        HStack(spacing: 10) {
                            if auth.isLoading {
                                ProgressView().tint(.white).scaleEffect(0.85)
                            } else {
                                Text("Send Reset Link")
                                    .font(.headline)
                                Image(systemName: "paperplane.fill")
                                    .font(.subheadline)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            isValidEmail(email)
                                ? AnyShapeStyle(Color.teal.gradient)
                                : AnyShapeStyle(Color.secondary.opacity(0.22)),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .disabled(!isValidEmail(email) || auth.isLoading)
                    .animation(.easeInOut(duration: 0.18), value: isValidEmail(email))
                }

                if sent {
                    Button("Back to Sign In") { dismiss() }
                        .font(.subheadline.bold())
                        .foregroundStyle(.teal)
                }

                Spacer()
            }
            .padding(28)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                email = prefillEmail
                auth.errorMessage = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
            }
        }
    }

    private func sendReset() {
        let e = email.trimmingCharacters(in: .whitespaces)
        guard isValidEmail(e) else { return }
        Task {
            let success = await auth.resetPassword(email: e)
            if success { sent = true }
        }
    }
}
