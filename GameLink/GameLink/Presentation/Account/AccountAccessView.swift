import SwiftUI

struct AccountAccessView: View {
  @Bindable var model: AccountViewModel
  let openLocalMode: () -> Void
  @State private var registering = false
  @FocusState private var focusedField: Field?

  private enum Field: Hashable { case email, password, repeatedPassword }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack(spacing: 12) {
            Image(systemName: "person.2.fill").font(.title)
            Text("GameLink").font(.largeTitle.bold())
          }
          .foregroundStyle(Color.accentColor)
        }
        Section {
          Picker("Account", selection: $registering) {
            Text("Sign in").tag(false)
            Text("Register").tag(true)
          }
          .pickerStyle(.segmented)
          TextField("Email", text: $model.email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit { focusedField = .password }
            .accessibilityIdentifier("accountEmail")
          SecureField("Password", text: $model.password)
            .textContentType(registering ? .newPassword : .password)
            .focused($focusedField, equals: .password)
            .submitLabel(registering ? .next : .go)
            .onSubmit {
              if registering { focusedField = .repeatedPassword } else { submit() }
            }
            .accessibilityIdentifier("accountPassword")
          if registering {
            SecureField("Confirm password", text: $model.repeatedPassword)
              .textContentType(.newPassword)
              .focused($focusedField, equals: .repeatedPassword)
              .submitLabel(.go)
              .onSubmit { submit() }
              .accessibilityIdentifier("accountRepeatedPassword")
            Text("Use at least 8 characters.").font(.callout)
          }
          Button(action: submit) {
            Text(registering ? "Create account" : "Sign in")
              .frame(maxWidth: .infinity, minHeight: 44)
          }
          .buttonStyle(.borderedProminent)
          .foregroundStyle(Color(.accentForeground))
          .accessibilityIdentifier("submitAccount")
        }
        .disabled(model.isBusy)
        .onChange(of: registering) { model.resetForm() }
        if model.isBusy { Section { ProgressView("Please wait…") } }
        if let failure = model.failure {
          Section { Text(failure.localizedDescription).foregroundStyle(.red) }
        }
        Section {
          Text("Accounts are stored on this device only.").font(.callout)
          Button("Continue without an account", action: openLocalMode)
            .frame(minHeight: 44)
            .disabled(model.isBusy)
            .accessibilityIdentifier("continueLocally")
        }
      }
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle(registering ? "Create account" : "Welcome")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private func submit() { perform { await model.submit(registering: registering) } }

  private func perform(_ action: @escaping @MainActor () async -> Void) {
    focusedField = nil
    Task { await action() }
  }
}

struct AccountSettingsSection: View {
  let model: AccountViewModel
  let leaveLocalMode: () -> Void
  @State private var confirmsSignOut = false

  var body: some View {
    Section("Account") {
      if let identity = model.identity {
        LabeledContent("Email", value: identity.email)
        Button("Sign out", role: .destructive) { confirmsSignOut = true }
          .disabled(model.isBusy)
          .accessibilityIdentifier("signOut")
        if let failure = model.failure { Text(failure.localizedDescription).font(.callout) }
      } else {
        Text("Local mode")
        Button("Sign in or register") { confirmsSignOut = true }
      }
    }
    .confirmationDialog("Leave this workspace?", isPresented: $confirmsSignOut) {
      Button(model.identity == nil ? "Open sign in" : "Sign out", role: .destructive) {
        if model.identity == nil { leaveLocalMode() } else { Task { await model.signOut() } }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Saved details stay on this device. Unsaved edits will be discarded.")
    }
  }
}
