//
// Coordinator+ShowHideSpinner.swift
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
import MBProgressHUD

extension Coordinator {
    func showLoadingHud() {
        guard let view = topMostViewController.view else { return }
        MBProgressHUD.showAdded(to: view, animated: true)
    }

    func hideLoadingHud() {
        guard let view = topMostViewController.view else { return }
        MBProgressHUD.hide(for: view, animated: true)
    }
}
