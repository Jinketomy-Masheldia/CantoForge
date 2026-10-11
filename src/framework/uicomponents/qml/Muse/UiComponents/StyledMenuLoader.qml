/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-CLA-applies
 *
 * MuseScore
 * Music Composition & Notation
 *
 * Copyright (C) 2021 MuseScore Limited and others
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
pragma ComponentBehavior: Bound

import QtQuick

import Muse.UiComponents

import "internal"

Loader {
    id: loader

    signal handleMenuItem(string itemId)
    signal openPrevMenu()
    signal openNextMenu()
    signal opened()
    signal closed(bool force)

    property StyledMenu menu: loader.item as StyledMenu
    property Item menuAnchorItem: null
    property bool hasSiblingMenus: false
    property var placementPolicies: PopupView.Default
    property var parentWindow: null
    property bool isSearchable: false
    property bool touchInteractionEnabled: Qt.platform.os === "ios"
    property alias isMenuOpened: loader.active

    property string accessibleName: ""
    property int menuGeneration: 0

    QtObject {
        id: prv

        function loadMenu() {
            loader.active = true
        }

        function unloadMenu(closedMenu, generation, force) {
            // A parent-row tap may reopen this loader before the old popup's
            // deferred close runs. Never unload the replacement menu.
            if (!closedMenu || loader.menu !== closedMenu || loader.menuGeneration !== generation || closedMenu.isOpened) {
                return
            }
            loader.active = false
            loader.closed(force)
        }
    }

    active: false

    sourceComponent: StyledMenu {
        id: itemMenu

        openPolicies: PopupView.NoActivateFocus
        focusPolicies: PopupView.NoFocus

        accessibleName: loader.accessibleName
        hasSiblingMenus: loader.hasSiblingMenus
        placementPolicies: loader.placementPolicies
        parentWindow: loader.parentWindow
        isSearchable: loader.isSearchable
        touchInteractionEnabled: loader.touchInteractionEnabled

        onHandleMenuItem: function(itemId) {
            itemMenu.close()
            Qt.callLater(loader.handleMenuItem, itemId)
        }

        onOpenPrevMenu: {
           Qt.callLater(loader.openPrevMenu)
        }

        onOpenNextMenu: {
            Qt.callLater(loader.openNextMenu)
        }

        onClosed: function(force) {
            focusOnOpenedMenuTimer.stop()
            Qt.callLater(prv.unloadMenu, itemMenu, loader.menuGeneration, force)
        }

        onOpened: {
            focusOnOpenedMenuTimer.start()
        }
    }

    function open(model, x = -1, y = -1) {
        ++loader.menuGeneration
        prv.loadMenu()

        var menu = loader.menu
        menu.parent = loader.parent
        menu.anchorItem = menuAnchorItem

        update(model, x, y)
        menu.open()

        Qt.callLater(loader.opened)
    }

    function toggleOpened(model, x = -1, y = -1) {
        prv.loadMenu()

        var menu = loader.menu
        if (menu.isOpened) {
            menu.close()
            return
        }

        open(model, x, y)
    }

    function toggleOpenedWithAlign(model, align) {
        prv.loadMenu()

        loader.menu.preferredAlign = align

        toggleOpened(model)
    }

    function close() {
        if (loader.isMenuOpened) {
            loader.menu.close()
        }
    }

    function update(model, x = -1, y = -1) {
        var menu = loader.menu
        if (!Boolean(menu)) {
            return
        }

        menu.closeSubMenu()

        menu.model = model

        if (x !== -1) {
            menu.x = x
        }

        if (y !== -1) {
            menu.y = y
        }
    }

    Timer {
        id: focusOnOpenedMenuTimer

        interval: 50
        running: false
        repeat: false

        onTriggered: {
            if (loader.menu) {
                loader.menu.requestFocus()
            }
        }
    }
}
