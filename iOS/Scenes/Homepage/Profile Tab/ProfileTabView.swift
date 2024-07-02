//
// ProfileTabView.swift
// Proton Pass - Created on 07/03/2023.
// Copyright (c) 2023 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Pass is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Pass is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.

import Core
import DesignSystem
import Entities
import Macro
import ProtonCoreUIFoundations
import Screens
import SwiftUI

struct UserAccountDetail: AccountCellDetail, Identifiable {
    let id: String
    let initials: String
    let displayName: String
    let email: String

    static var empty: UserAccountDetail {
        UserAccountDetail(id: UUID().uuidString,
                          initials: "",
                          displayName: "",
                          email: "")
    }
}

// swiftlint:disable:next type_body_length
struct ProfileTabView: View {
    @StateObject var viewModel: ProfileTabViewModel
    @Namespace private var animationNamespace
    @State private var showSwitcher = false
    @State private var accountToSignOut: UserAccountDetail?

    var body: some View {
        mainContainer
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .background(PassColor.backgroundNorm.toColor)
            .toolbar { toolbarContent }
            .if(viewModel.currentActiveUser) { view, currentActiveUser in
                view
                    .modifier(AccountSwitchModifier(details: viewModel.userAccounts,
                                                    activeId: currentActiveUser.id,
                                                    showSwitcher: $showSwitcher,
                                                    animationNamespace: animationNamespace,
                                                    onSelect: { viewModel.switchUser(userId: $0) },
                                                    onManage: { _ in
                                                        handleManage()
                                                    },
                                                    onSignOut: { handleSignOut($0) },
                                                    onAddAccount: { handleAddAccount() }))
            }
            .alert(item: $accountToSignOut) { user in
                Alert(title: Text("You will be signed out"),
                      message: Text("Account name: \(user.displayName) and email: \(user.email)"),
                      primaryButton: .destructive(Text("Yes, sign me out")) {
                          viewModel.signOut(user: user)
                      }, secondaryButton: .cancel())
            }
            .navigationStackEmbeded()
            .task {
                await viewModel.refreshPlan()
            }
            .onAppear {
                viewModel.fetchSecureLinks()
            }
    }

    var mainContainer: some View {
        ScrollView {
            VStack {
                accountSection

                itemCountSection

                securitySection
                    .padding(.vertical)

                if viewModel.autoFillEnabled {
                    autoFillEnabledSection
                } else {
                    autoFillDisabledSection
                }

                if viewModel.isSecureLinkActive {
                    secureLinkSection
                        .padding(.vertical)
                }

                accountAndSettingsSection
                    .padding(.vertical)

                aboutSection

                helpCenterSection
                    .padding(.vertical)

                if Bundle.main.isQaBuild {
                    qaFeaturesSection
                }

                Text("Version \(Bundle.main.displayedAppVersion)")
                    .sectionTitleText()
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
            .padding(.top)
            .animation(.default, value: viewModel.showAutomaticCopyTotpCodeExplanation)
            .animation(.default, value: viewModel.localAuthenticationMethod)
        }
    }

    func handleManage() {
        dismissAccountSwitcherAndDisplay()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            viewModel.showAccountMenu()
        }
    }

    func handleSignOut(_ id: any AccountCellDetail) {
        dismissAccountSwitcherAndDisplay()
        accountToSignOut = id as? UserAccountDetail
    }

    func handleAddAccount() {
        dismissAccountSwitcherAndDisplay()
    }

    func dismissAccountSwitcherAndDisplay() {
        withAnimation {
            showSwitcher.toggle()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if viewModel.plan?.hideUpgrade == false {
                CapsuleLabelButton(icon: PassIcon.brandPass,
                                   title: #localized("Upgrade"),
                                   titleColor: PassColor.interactionNorm,
                                   backgroundColor: PassColor.interactionNormMinor2,
                                   action: { viewModel.upgrade() })
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        if let activeUser = viewModel.currentActiveUser {
            VStack {
                Text("Account")
                    .profileSectionTitle()

                Group {
                    if !showSwitcher {
                        AccountCell(detail: activeUser,
                                    animationNamespace: animationNamespace)
                            .animation(.default, value: showSwitcher)
                            .onTapGesture {
                                if viewModel.isMultiAccountActive {
                                    withAnimation {
                                        showSwitcher.toggle()
                                    }
                                } else {
                                    viewModel.showAccountMenu()
                                }
                            }
                    } else {
                        AccountCell(detail: UserAccountDetail.empty,
                                    animationNamespace: animationNamespace)
                    }
                }
                .padding()
                .roundedEditableSection()
            }.padding()
        }
    }

    private var itemCountSection: some View {
        VStack {
            Text("Items")
                .profileSectionTitle()
                .padding(.horizontal)
            ItemCountView()
        }
    }

    private var securitySection: some View {
        VStack(spacing: 0) {
            Text("Security")
                .profileSectionTitle()
                .padding(.bottom, DesignConstant.sectionPadding)

            VStack(spacing: 0) {
                OptionRow(action: { viewModel.editLocalAuthenticationMethod() },
                          height: .tall,
                          content: {
                              VStack(alignment: .leading, spacing: DesignConstant.sectionPadding / 2) {
                                  Text("Unlock with")
                                      .sectionTitleText()

                                  Text(viewModel.localAuthenticationMethod.title)
                                      .foregroundStyle(PassColor.textNorm.toColor)
                              }
                          },
                          trailing: { ChevronRight() })

                if viewModel.localAuthenticationMethod != .none {
                    PassDivider()

                    OptionRow(action: { viewModel.editAppLockTime() },
                              height: .tall,
                              content: {
                                  VStack(alignment: .leading, spacing: DesignConstant.sectionPadding / 2) {
                                      Text("Automatic lock")
                                          .sectionTitleText()

                                      Text(viewModel.appLockTime.description)
                                          .foregroundStyle(PassColor.textNorm.toColor)
                                  }
                              },
                              trailing: {
                                  if viewModel.canUpdateAppLockTime {
                                      ChevronRight()
                                  }
                              })
                              .disabled(!viewModel.canUpdateAppLockTime)
                }

                switch viewModel.localAuthenticationMethod {
                case .none:
                    EmptyView()

                case let .biometric(type):
                    PassDivider()

                    OptionRow(height: .tall) {
                        StaticToggle(type.fallbackToPasscodeMessage,
                                     isOn: viewModel.fallbackToPasscode,
                                     action: { viewModel.toggleFallbackToPasscode() })
                    }

                case .pin:
                    PassDivider()

                    OptionRow(action: { viewModel.editPINCode() },
                              height: .medium,
                              content: {
                                  HStack {
                                      Text("Change PIN code")
                                      Spacer()
                                      CircleButton(icon: IconProvider.grid3,
                                                   iconColor: PassColor.interactionNormMajor2,
                                                   backgroundColor: PassColor.interactionNormMinor1,
                                                   action: nil)
                                  }
                                  .foregroundStyle(PassColor.interactionNormMajor2.toColor)
                              })
                }
            }
            .roundedEditableSection()
        }
        .padding(.horizontal)
    }

    private var autoFillDisabledSection: some View {
        VStack(spacing: 0) {
            OptionRow(height: .medium) {
                HStack {
                    Text("AutoFill disabled")
                        .foregroundStyle(PassColor.textNorm.toColor)

                    Spacer()

                    Button { viewModel.handleEnableAutoFillAction() } label: {
                        Label(ProcessInfo.processInfo.isiOSAppOnMac ? "Show me how" : "Open Settings",
                              systemImage: "arrow.up.right.square")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(PassColor.interactionNormMajor2.toColor)
                    }
                }
            }
            .roundedEditableSection()

            Text("AutoFill on apps and websites by enabling Proton Pass AutoFill")
                .sectionTitleText()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DesignConstant.sectionPadding / 2)
        }
        .padding(.horizontal)
    }

    private var autoFillEnabledSection: some View {
        VStack {
            VStack(spacing: 0) {
                OptionRow(height: .medium) {
                    StaticToggle("QuickType bar suggestions",
                                 isOn: viewModel.quickTypeBar,
                                 action: { viewModel.toggleQuickTypeBar() })
                }

                PassSectionDivider()

                OptionRow(height: .medium) {
                    StaticToggle("Copy 2FA code",
                                 isOn: viewModel.automaticallyCopyTotpCode,
                                 action: { viewModel.toggleAutomaticCopyTotpCode() })
                }
            }
            .roundedEditableSection()

            if viewModel.showAutomaticCopyTotpCodeExplanation {
                Text("Automatic copy of the 2FA code requires biometric lock or PIN code to be set up")
                    .sectionTitleText()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var secureLinkSection: some View {
        let isFreeUser = viewModel.plan?.isFreeUser
        VStack(spacing: 0) {
            OptionRow(action: {
                          if let isFreeUser, isFreeUser {
                              viewModel.upsell(entryPoint: .secureLink)
                          } else {
                              viewModel.showSecureLinkList()
                          }
                      },
                      height: .tall,
                      content: {
                          HStack(spacing: DesignConstant.sectionPadding / 2) {
                              Text("Secure link")
                                  .foregroundStyle(PassColor.textNorm.toColor)

                              Spacer()

                              if let isFreeUser, !isFreeUser, let secureLinks = viewModel.secureLinks {
                                  CapsuleCounter(count: secureLinks.count,
                                                 foregroundStyle: PassColor.textNorm.toColor,
                                                 background: PassColor.backgroundMedium.toColor)
                              }
                          }
                      },
                      trailing: {
                          if let isFreeUser, isFreeUser {
                              Image(uiImage: PassIcon.passSubscriptionBadge)
                                  .resizable()
                                  .scaledToFit()
                                  .frame(height: 24)
                          } else {
                              ChevronRight()
                          }
                      })
        }
        .roundedEditableSection()
        .padding(.horizontal)
    }

    private var accountAndSettingsSection: some View {
        VStack(spacing: 0) {
            OptionRow(action: { viewModel.showAccountMenu() },
                      content: {
                          HStack {
                              Text("Account")
                                  .foregroundStyle(PassColor.textNorm.toColor)

                              Spacer()

                              if let associatedPlanInfo = viewModel.plan?.associatedPlanInfo {
                                  Label(title: {
                                      Text(associatedPlanInfo.title)
                                          .font(.callout)
                                  }, icon: {
                                      Image(uiImage: associatedPlanInfo.icon)
                                          .resizable()
                                          .scaledToFit()
                                          .frame(maxWidth: associatedPlanInfo.iconWidth)
                                  })
                                  .foregroundStyle(associatedPlanInfo.tintColor.toColor)
                                  .padding(.horizontal)
                              }
                          }
                      },
                      trailing: { ChevronRight() })

            PassSectionDivider()

            TextOptionRow(title: #localized("Settings"), action: { viewModel.showSettingsMenu() })
        }
        .roundedEditableSection()
        .padding(.horizontal)
    }

    private var aboutSection: some View {
        VStack(spacing: 0) {
            TextOptionRow(title: #localized("Privacy policy"), action: { viewModel.showPrivacyPolicy() })
            PassSectionDivider()
            TextOptionRow(title: #localized("Terms of service"), action: { viewModel.showTermsOfService() })
        }
        .roundedEditableSection()
        .padding(.horizontal)
    }

    private var helpCenterSection: some View {
        VStack(spacing: 0) {
            Text("Help center")
                .profileSectionTitle()
                .padding(.bottom, DesignConstant.sectionPadding)

            VStack(spacing: 0) {
                TextOptionRow(title: #localized("How to import to Proton Pass"),
                              action: { viewModel.showImportInstructions() })

                PassSectionDivider()
                TextOptionRow(title: #localized("Feedback"), action: { viewModel.showFeedback() })

                PassSectionDivider()
                OptionRow(action: { viewModel.showTutorial() },
                          content: {
                              Text("How to use Proton Pass")
                                  .foregroundStyle(PassColor.textNorm.toColor)
                          },
                          trailing: {
                              Image(uiImage: IconProvider.arrowOutSquare)
                                  .resizable()
                                  .scaledToFit()
                                  .frame(height: 16)
                                  .foregroundStyle(PassColor.textHint.toColor)
                          })
            }
            .roundedEditableSection()
        }
        .padding(.horizontal)
    }

    private var qaFeaturesSection: some View {
        VStack(spacing: 0) {
            TextOptionRow(title: "QA Features", action: { viewModel.qaFeatures() })
        }
        .roundedEditableSection()
        .padding(.horizontal)
    }
}

private extension View {
    func profileSectionTitle() -> some View {
        foregroundStyle(PassColor.textNorm.toColor)
            .font(.callout.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AssociatedPlanInfo {
    let title: String
    let icon: UIImage
    let iconWidth: CGFloat
    let tintColor: UIColor
}

private extension Plan {
    var associatedPlanInfo: AssociatedPlanInfo? {
        switch planType {
        case .free:
            nil

        case .trial:
            .init(title: #localized("Free trial"),
                  icon: PassIcon.badgeTrial,
                  iconWidth: 12,
                  tintColor: PassColor.interactionNormMajor2)

        case .business, .plus:
            .init(title: displayName,
                  icon: PassIcon.badgePaid,
                  iconWidth: 16,
                  tintColor: PassColor.noteInteractionNormMajor2)
        }
    }
}

@MainActor
struct SentinelSheetView: View {
    @Binding var isPresented: Bool
    let noBackgroundSheet: Bool
    let sentinelActive: Bool
    let mainAction: () -> Void
    let secondaryAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if noBackgroundSheet {
                background
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            } else {
                background
            }

            ViewThatFits(in: .vertical) {
                mainSentinelSheet.padding()
                ScrollView(showsIndicators: false) {
                    mainSentinelSheet
                }.padding()
            }

            Button { isPresented = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .padding(4)
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.black.opacity(0.7))
            }
            .buttonStyle(.plain)
            .padding()
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var mainSentinelSheet: some View {
        let isIpad = UIDevice.current.isIpad
        VStack(spacing: DesignConstant.sectionPadding) {
            if isIpad {
                Spacer()
            }
            Image(uiImage: PassIcon.netShield)
                .resizable()
                .scaledToFit()
            if isIpad {
                Spacer()
            }
            VStack(spacing: 8) {
                Text("Proton Sentinel")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(PassColor.textInvert.toColor)

                Text("Sentinel description")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PassColor.textInvert.toColor)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.bottom, 8)
            }
            VStack(spacing: 8) {
                CapsuleTextButton(title: sentinelActive ? #localized("Disable Proton Sentinel") :
                    #localized("Enable Proton Sentinel"),
                    titleColor: PassColor.interactionNormMinor1,
                    backgroundColor: PassColor.interactionNormMajor2,
                    height: 48,
                    action: mainAction)
                    .padding(.horizontal, DesignConstant.sectionPadding)

                CapsuleTextButton(title: #localized("Learn more"),
                                  titleColor: PassColor.interactionNormMajor2,
                                  backgroundColor: PassColor.interactionNormMinor1,
                                  height: 48,
                                  action: secondaryAction)
                    .padding(.horizontal, DesignConstant.sectionPadding)
            }
            if isIpad {
                Spacer()
            }
        }
    }

    private var background: some View {
        Group {
            Color.white
            LinearGradient(colors: [
                .clear,
                Color(red: 112 / 255, green: 76 / 255, blue: 225 / 255, opacity: 0.15)
            ],
            startPoint: .top,
            endPoint: .bottom)
        }
    }
}
