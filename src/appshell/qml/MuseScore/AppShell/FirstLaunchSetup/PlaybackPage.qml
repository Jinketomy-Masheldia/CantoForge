/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
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
import QtQuick
import QtQuick.Window
import QtQuick.Layouts

import Muse.Ui
import Muse.UiComponents
import Muse.GraphicalEffects
import MuseScore.AppShell

Page {
    title: Qt.platform.os === "ios" ? qsTrc("appshell/gettingstarted", "About CantoForge")
                                    : qsTrc("appshell/gettingstarted", "Playback")
    explanation: Qt.platform.os === "ios" ? qsTrc("appshell/gettingstarted", "An unofficial iPadOS port of MuseScore Studio.")
                                          : qsTrc("appshell/gettingstarted", "Discover new sound libraries in MuseHub and enjoy realistic score playback")

    titleContentSpacing: 12

    extraButtonTitle: Qt.platform.os === "ios" ? "" : qsTrc("appshell/gettingstarted", "Watch video")

    onExtraButtonClicked: {
        Qt.openUrlExternally("https://youtu.be/L8OdWHOjL8c")
    }

    Image {
        id: image
        visible: Qt.platform.os !== "ios"
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: "resources/MuseSounds.png"
        sourceSize: Qt.size(width * Screen.devicePixelRatio, height * Screen.devicePixelRatio)

        layer.enabled: ui.isEffectsAllowed
        layer.effect: RoundedCornersEffect {
            radius: 3
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: Qt.platform.os === "ios"
        spacing: 12

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 80
            Layout.preferredHeight: 80
            source: "qrc:/resources/appIcon.png"
            fillMode: Image.PreserveAspectFit
        }

        StyledTextLabel {
            Layout.fillWidth: true
            text: qsTrc("appshell/gettingstarted", "CantoForge is an independent project based on MuseScore Studio 4.7.5. It is not affiliated with or endorsed by MuseScore or Muse Group.")
            wrapMode: Text.WordWrap
        }

        StyledTextLabel {
            Layout.fillWidth: true
            text: qsTrc("appshell/gettingstarted", "The desktop interface and core notation features are retained. Some desktop integrations are unavailable on iPadOS.")
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }
    }
}
