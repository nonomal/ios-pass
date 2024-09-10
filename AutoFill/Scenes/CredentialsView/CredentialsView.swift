//
// CredentialsView.swift
// Proton Pass - Created on 27/09/2022.
// Copyright (c) 2022 Proton Technologies AG
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

import Client
import Combine
import DesignSystem
import Entities
import Factory
import Macro
import ProtonCoreUIFoundations
import Screens
import SwiftUI

struct CredentialsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: CredentialsViewModel
    @FocusState private var isFocusedOnSearchBar
    @State private var showUserList = false

    init(viewModel: CredentialsViewModel) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            PassColor.backgroundNorm.toColor
                .ignoresSafeArea()
            stateViews
        }
        .task {
            await viewModel.fetchItems()
            await viewModel.sync()
        }
        .localAuthentication(onSuccess: { _ in viewModel.handleAuthenticationSuccess() },
                             onFailure: { _ in viewModel.handleAuthenticationFailure() })
        .alert("Associate URL?",
               isPresented: $viewModel.isShowingConfirmationAlert,
               actions: {
                   if let information = viewModel.notMatchedItemInformation {
                       Button(action: {
                           viewModel.associateAndAutofill(item: information.item)
                       }, label: {
                           Text("Associate and autofill")
                       })

                       Button(action: {
                           viewModel.select(item: information.item)
                       }, label: {
                           Text("Just autofill")
                       })
                   }

                   Button(role: .cancel) {
                       Text("Cancel")
                   }
               },
               message: {
                   if let information = viewModel.notMatchedItemInformation {
                       // swiftlint:disable:next line_length
                       Text("Would you want to associate « \(information.url) » with « \(information.item.itemTitle) »?")
                   }
               })
        .sheet(isPresented: selectPasskeySheetBinding) {
            if let info = viewModel.selectPasskeySheetInformation,
               let context = viewModel.context {
                SelectPasskeyView(info: info, context: context)
                    .presentationDetents([.height(CGFloat(info.passkeys.count * 60) + 80)])
            }
        }
        .confirmationDialog("Create",
                            isPresented: $showUserList,
                            actions: {
                                ForEach(viewModel.users) { user in
                                    Button(action: {
                                        viewModel.createNewItem(userId: user.id)
                                    }, label: {
                                        Text(verbatim: user.email ?? user.displayName ?? "?")
                                    })
                                }

                                Button("Cancel", role: .cancel, action: {})
                            },
                            message: {
                                Text("Select account")
                            })
    }
}

private extension CredentialsView {
    @ViewBuilder
    var stateViews: some View {
        VStack(spacing: 0) {
            if viewModel.state != .loading {
                let placeholder = if viewModel.selectedUser == nil {
                    #localized("Search in %lld accounts", viewModel.users.count)
                } else {
                    viewModel.planType.searchBarPlaceholder
                }
                SearchBar(query: $viewModel.query,
                          isFocused: $isFocusedOnSearchBar,
                          placeholder: placeholder,
                          onCancel: { viewModel.cancel() })
            }
            switch viewModel.state {
            case .idle:
                accountSwitcher

                if let planType = viewModel.planType, case .free = planType {
                    mainVaultsOnlyMessage
                }

                if !viewModel.results.isEmpty {
                    if viewModel.matchedItems.isEmpty,
                       viewModel.notMatchedItems.isEmpty {
                        VStack {
                            Spacer()
                            Text("You currently have no login items")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(PassColor.textNorm.toColor)
                                .padding()
                            Spacer()
                        }
                    } else {
                        itemList(matchedItems: viewModel.matchedItems,
                                 notMatchedItems: viewModel.notMatchedItems)
                    }
                }
            case .searching:
                ProgressView()
            case let .searchResults(results):
                if results.isEmpty {
                    NoSearchResultsInAllVaultView(query: viewModel.query)
                } else {
                    let getUser: (any ItemIdentifiable) -> PassUser? = { item in
                        if viewModel.users.count > 1, viewModel.selectedUser == nil {
                            return viewModel.getUser(for: item)
                        }
                        return nil
                    }
                    CredentialSearchResultView(results: results,
                                               getUser: getUser,
                                               selectedSortType: $viewModel.selectedSortType,
                                               sortAction: { viewModel.presentSortTypeList() },
                                               selectItem: { viewModel.select(item: $0) })
                }
            case .loading:
                CredentialsSkeletonView()
            case let .error(error):
                RetryableErrorView(errorMessage: error.localizedDescription,
                                   onRetry: { viewModel.fetchItemsSync() })
            }

            Spacer()

            CapsuleTextButton(title: #localized("Create login"),
                              titleColor: PassColor.loginInteractionNormMajor2,
                              backgroundColor: PassColor.loginInteractionNormMinor1,
                              height: 52,
                              action: {
                                  if viewModel.shouldAskForUserWhenCreatingNewItem {
                                      showUserList.toggle()
                                  } else {
                                      viewModel.createNewItem(userId: nil)
                                  }
                              })
                              .padding(.horizontal)
                              .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.default, value: viewModel.state)
        .animation(.default, value: viewModel.planType)
        .animation(.default, value: viewModel.results)
    }
}

private extension CredentialsView {
    var selectPasskeySheetBinding: Binding<Bool> {
        .init(get: {
            viewModel.selectPasskeySheetInformation != nil
        }, set: { newValue in
            if !newValue {
                viewModel.selectPasskeySheetInformation = nil
            }
        })
    }
}

// MARK: ResultView & elements

private extension CredentialsView {
    @ViewBuilder
    var accountSwitcher: some View {
        if viewModel.users.count > 1 {
            let allAccountsMessage = #localized("All %lld accounts", viewModel.users.count)
            Menu(content: {
                Button(action: {
                    viewModel.selectedUser = nil
                }, label: {
                    if viewModel.selectedUser == nil {
                        Label(allAccountsMessage, systemImage: "checkmark")
                    } else {
                        Text(verbatim: allAccountsMessage)
                    }
                })

                Section {
                    ForEach(viewModel.users) { user in
                        Button(action: {
                            viewModel.selectedUser = user
                        }, label: {
                            if user == viewModel.selectedUser {
                                Label(user.email ?? "?", systemImage: "checkmark")
                            } else {
                                Text(verbatim: user.email ?? "?")
                            }
                        })
                    }
                }
            }, label: {
                HStack {
                    if let selectedUser = viewModel.selectedUser {
                        Text(verbatim: selectedUser.displayNameAndEmail)
                            .font(.callout)
                            .foregroundStyle(PassColor.textInvert.toColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PassColor.interactionNormMajor2.toColor)
                            .clipShape(Capsule())
                    } else {
                        Text(verbatim: allAccountsMessage)
                            .fontWeight(.medium)
                            .foregroundStyle(PassColor.interactionNormMajor2.toColor)
                    }

                    Spacer()
                }
            })
            .padding([.horizontal, .bottom])
        }
    }

    func itemList(matchedItems: [ItemUiModel],
                  notMatchedItems: [ItemUiModel]) -> some View {
        ScrollViewReader { proxy in
            List {
                matchedItemsSection(matchedItems)
                notMatchedItemsSection(notMatchedItems)
            }
            .listStyle(.plain)
            .refreshable { await viewModel.sync() }
            .animation(.default, value: matchedItems.hashValue)
            .animation(.default, value: notMatchedItems.hashValue)
            .overlay {
                if viewModel.selectedSortType.isAlphabetical {
                    HStack {
                        Spacer()
                        SectionIndexTitles(proxy: proxy,
                                           direction: viewModel.selectedSortType.sortDirection ?? .ascending)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func matchedItemsSection(_ items: [ItemUiModel]) -> some View {
        let sectionTitle = #localized("Suggestions for %@", viewModel.domain)
        if items.isEmpty {
            Section(content: {
                Text("No suggestions")
                    .font(.callout.italic())
                    .padding(.horizontal)
                    .foregroundStyle(PassColor.textWeak.toColor)
                    .plainListRow()
            }, header: {
                Text(sectionTitle)
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(PassColor.textNorm.toColor)
            })
        } else {
            section(for: items,
                    headerTitle: sectionTitle,
                    headerColor: PassColor.textNorm,
                    headerFontWeight: .bold)
        }
    }

    @ViewBuilder
    func notMatchedItemsSection(_ items: [ItemUiModel]) -> some View {
        if !items.isEmpty {
            HStack {
                Text("Other items")
                    .font(.callout)
                    .fontWeight(.bold)
                    .adaptiveForegroundStyle(PassColor.textNorm.toColor) +
                    Text(verbatim: " (\(items.count))")
                    .font(.callout)
                    .adaptiveForegroundStyle(PassColor.textWeak.toColor)

                Spacer()

                SortTypeButton(selectedSortType: $viewModel.selectedSortType,
                               action: { viewModel.presentSortTypeList() })
            }
            .plainListRow()
            .padding([.top, .horizontal])
            sortableSections(for: items)
        }
    }

    var mainVaultsOnlyMessage: some View {
        ZStack {
            Text("Your plan only allows to use items from your first 2 vaults for autofill purposes.")
                .adaptiveForegroundStyle(PassColor.textNorm.toColor) +
                Text(verbatim: " ") +
                Text("Upgrade now")
                .underline(color: PassColor.interactionNormMajor1.toColor)
                .adaptiveForegroundStyle(PassColor.interactionNormMajor1.toColor)
        }
        .padding()
        .background(PassColor.interactionNormMinor1.toColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(perform: viewModel.upgrade)
    }
}

// MARK: Sections & elements

private extension CredentialsView {
    @ViewBuilder
    func section(for items: [some CredentialItem],
                 headerTitle: String,
                 headerColor: UIColor = PassColor.textWeak,
                 headerFontWeight: Font.Weight = .regular) -> some View {
        if items.isEmpty {
            EmptyView()
        } else {
            Section(content: {
                ForEach(items) { item in
                    let user = viewModel.selectedUser == nil ? viewModel.getUser(for: item) : nil
                    GenericCredentialItemRow(item: item,
                                             user: user,
                                             selectItem: { viewModel.select(item: $0) })
                        .plainListRow()
                        .padding(.horizontal)
                }
            }, header: {
                Text(headerTitle)
                    .font(.callout)
                    .fontWeight(headerFontWeight)
                    .foregroundStyle(headerColor.toColor)
            })
        }
    }

    @ViewBuilder
    func sortableSections(for items: [some CredentialItem]) -> some View {
        switch viewModel.selectedSortType {
        case .mostRecent:
            sections(for: items.mostRecentSortResult())
        case .alphabeticalAsc:
            sections(for: items.alphabeticalSortResult(direction: .ascending))
        case .alphabeticalDesc:
            sections(for: items.alphabeticalSortResult(direction: .descending))
        case .newestToOldest:
            sections(for: items.monthYearSortResult(direction: .descending))
        case .oldestToNewest:
            sections(for: items.monthYearSortResult(direction: .ascending))
        }
    }

    func sections(for result: MostRecentSortResult<some CredentialItem>) -> some View {
        Group {
            section(for: result.today, headerTitle: #localized("Today"))
            section(for: result.yesterday, headerTitle: #localized("Yesterday"))
            section(for: result.last7Days, headerTitle: #localized("Last week"))
            section(for: result.last14Days, headerTitle: #localized("Last two weeks"))
            section(for: result.last30Days, headerTitle: #localized("Last 30 days"))
            section(for: result.last60Days, headerTitle: #localized("Last 60 days"))
            section(for: result.last90Days, headerTitle: #localized("Last 90 days"))
            section(for: result.others, headerTitle: #localized("More than 90 days"))
        }
    }

    func sections(for result: AlphabeticalSortResult<some CredentialItem>) -> some View {
        ForEach(result.buckets, id: \.letter) { bucket in
            section(for: bucket.items, headerTitle: bucket.letter.character)
                .id(bucket.letter.character)
        }
    }

    func sections(for result: MonthYearSortResult<some CredentialItem>) -> some View {
        ForEach(result.buckets, id: \.monthYear) { bucket in
            section(for: bucket.items, headerTitle: bucket.monthYear.relativeString)
        }
    }
}

// MARK: SkeletonView

private struct CredentialsSkeletonView: View {
    var body: some View {
        VStack {
            HStack {
                SkeletonBlock()
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                SkeletonBlock()
                    .frame(width: DesignConstant.searchBarHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .frame(height: DesignConstant.searchBarHeight)
            .padding(.vertical)
            .shimmering()

            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(0..<20, id: \.self) { _ in
                        itemRow
                    }
                }
            }
            .disabled(true)
        }
        .padding(.horizontal)
    }

    private var itemRow: some View {
        HStack(spacing: 16) {
            SkeletonBlock()
                .frame(width: 40, height: 40)
                .clipShape(Circle())

            VStack(alignment: .leading) {
                Spacer()
                SkeletonBlock()
                    .frame(width: 170, height: 10)
                    .clipShape(Capsule())
                Spacer()
                SkeletonBlock()
                    .frame(width: 200, height: 10)
                    .clipShape(Capsule())
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .shimmering()
    }
}

private extension Plan.PlanType? {
    var searchBarPlaceholder: String {
        switch self {
        case .free:
            #localized("Search in oldest 2 vaults")
        default:
            #localized("Search in all vaults")
        }
    }
}
