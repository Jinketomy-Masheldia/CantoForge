/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Copyright (C) 2022 MuseScore Limited and others
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
import QtQuick

import Muse.Ui
import Muse.UiComponents

import MuseScore.Inspector
import MuseScore.NotationScene
import MuseScore.Playback

Item {
    id: container

    property AbstractElementPopup popup: loader.item as AbstractElementPopup
    property bool isPopupOpened: Boolean(popup) && popup.isOpened

    property NavigationSection notationViewNavigationSection: null
    property int navigationOrderStart: 0
    property int navigationOrderEnd: Boolean(loader.item)
                                        ? loader.item.navigationOrderEnd
                                        : navigationOrderStart

    signal opened(var popupType)
    signal closed()

    QtObject {
        id: prv

        function componentByType(type) {
            switch (type) {
            case AbstractElementPopupModel.TYPE_HARP_DIAGRAM: return harpPedalComp
            case AbstractElementPopupModel.TYPE_CAPO: return capoComp
            case AbstractElementPopupModel.TYPE_STRING_TUNINGS: return stringTuningsComp
            case AbstractElementPopupModel.TYPE_SOUND_FLAG: return soundFlagComp
            case AbstractElementPopupModel.TYPE_STAFF_VISIBILITY: return staffVisibilityComp
            case AbstractElementPopupModel.TYPE_DYNAMIC: return dynamicComp
            case AbstractElementPopupModel.TYPE_TEXT: return textStyleComp
            case AbstractElementPopupModel.TYPE_PARTIAL_TIE: return partialTieComp
            case AbstractElementPopupModel.TYPE_SHADOW_NOTE: return shadowNoteComp
            }

            return null
        }

        function updateContainerPosition() {
            if (!Boolean(container.popup)) {
                return
            }

            // If mouse is hovering over the popup, don't update the position
            // to avoid jumps while the user is interacting with it
            if (container.popup.containsMouse) {
                return
            }

            const elementRect = container.popup.elementRect

            container.x = elementRect.x
            container.y = elementRect.y
            container.height = elementRect.height
            container.width = elementRect.width

            container.popup.updatePosition()
        }
    }

    function show(popupType) {
        close()

        var popup = loader.loadPopup(popupType)
        popup.open()
    }

    function close() {
        if (Boolean(container.popup) && container.popup.isOpened) {
            container.popup.close()
        }
    }

    Loader {
        id: loader

        anchors.fill: parent
        active: false

        function loadPopup(popupType) {
            // Recreate the model even when switching between two elements
            // with the same popup type while the old cleanup is pending.
            loader.active = false
            loader.sourceComponent = prv.componentByType(popupType)
            loader.active = true

            const popup = loader.item as AbstractElementPopup
            console.assert(popup)

            popup.parent = container

            popup.opened.connect(function() {
                container.opened(popupType)
            })

            popup.closed.connect(function() {
                // Keep the popup and its native window alive until the close
                // event has finished. A new popup may open before cleanup runs.
                Qt.callLater(loader.unloadPopup, popup)
            })

            prv.updateContainerPosition()
            popup.elementRectChanged.connect(prv.updateContainerPosition)
            popup.containsMouseChanged.connect(function() {
                if (!popup.containsMouse) {
                    prv.updateContainerPosition()
                }
            })

            //! NOTE: All navigation panels in popups must be in the notation view section.
            //        This is necessary so that popups do not activate navigation in the new section,
            //        but at the same time, when clicking on the component (text input), the focus in popup's window should be activated
            popup.navigationSection = null
            popup.openPolicies = PopupView.NoActivateFocus

            popup.notationViewNavigationSection = container.notationViewNavigationSection
            popup.navigationOrderStart = container.navigationOrderStart

            return popup
        }

        function unloadPopup(closedPopup) {
            if (!closedPopup || loader.item !== closedPopup || closedPopup.isOpened) {
                return
            }
            loader.active = false
            loader.sourceComponent = null
            container.closed()
        }
    }

    Component {
        id: harpPedalComp
        HarpPedalPopup {
        }
    }

    Component {
        id: capoComp
        CapoPopup {
        }
    }

    Component {
        id: stringTuningsComp
        StringTuningsPopup {
        }
    }

    Component {
        id: soundFlagComp
        SoundFlagPopup {
        }
    }

    Component {
        id: staffVisibilityComp
        StaffVisibilityPopup {
        }
    }

    Component {
        id: dynamicComp
        DynamicPopup {
        }
    }

    Component {
        id: textStyleComp
        TextStylePopup {
        }
    }

    Component {
        id: partialTieComp
        PartialTiePopup {
        }
    }

    Component {
        id: shadowNoteComp
        ShadowNotePopup {
        }
    }
}
