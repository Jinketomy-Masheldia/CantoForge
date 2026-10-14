/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Copyright (C) 2025 MuseScore Limited and others
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

import Muse.UiComponents
import MuseScore.Preferences

import "internal"

PreferencesPage {
    id: root

    VideoPreferencesModel {
        id: videoPreferencesModel
    }

    Component.onCompleted: {
        videoPreferencesModel.load()
    }

    Column {
        width: parent ? parent.width : implicitWidth
        spacing: root.sectionsSpacing

        FFmpegSection {
            visible: !videoPreferencesModel.usesSystemVideoEncoder
            model: videoPreferencesModel

            navigation.section: root.navigationSection
            navigation.order: root.navigationOrderStart + 1
        }

        BaseSection {
            width: parent ? parent.width : implicitWidth
            visible: videoPreferencesModel.usesSystemVideoEncoder
            title: qsTrc("preferences", "Video converter")
            navigation.section: root.navigationSection
            navigation.order: root.navigationOrderStart + 1

            StyledTextLabel {
                width: parent ? parent.width : implicitWidth
                text: qsTrc("cantoforge/video", "Video export uses the iPadOS system encoder. No additional installation is required.")
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.WordWrap
            }
        }
    }
}
