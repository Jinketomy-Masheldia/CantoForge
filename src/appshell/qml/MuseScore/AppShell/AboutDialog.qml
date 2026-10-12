/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Copyright (C) 2021-2024 MuseScore Limited and others
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

import MuseScore.AppShell

StyledDialogView {
    id: root

    readonly property bool isIos: Qt.platform.os === "ios"

    title: Qt.platform.os === "ios" ? qsTrc("appshell/about", "About CantoForge")
                                    : qsTrc("appshell/about", "About MuseScore Studio")

    contentHeight: root.isIos ? Math.min(600, Math.max(300, Screen.height - 80))
                              : Math.max(424, content.implicitHeight + 36 + aboutLayout.spacing + footer.implicitHeight + 16)
    contentWidth: root.isIos ? Math.min(480, Screen.width - 40) : 480

    AboutModel {
        id: aboutModel
    }

    ColumnLayout {
        id: aboutLayout

        anchors.fill: parent
        spacing: root.isIos ? 16 : 30

        StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: root.isIos ? 20 : 36
            Layout.leftMargin: 40
            Layout.rightMargin: 40
            contentWidth: width
            contentHeight: content.implicitHeight
            flickableDirection: Flickable.VerticalFlick

            ColumnLayout {
                id: content
                width: parent.width
                spacing: root.isIos ? 16 : 32

                Image {
                    id: logo
                    Layout.alignment: Qt.AlignHCenter

                    source: Qt.platform.os === "ios" ? "qrc:/resources/appIcon.png" : "resources/mu_logo.svg"
                    sourceSize: Qt.size(100, 100)

                    MouseArea {
                        anchors.fill: parent

                        property int clickCount: 0

                        onClicked: {
                            clickCount++

                            if (clickCount % 3 == 0) {
                                aboutModel.toggleDevMode()
                            }
                        }
                    }
                }

                StyledTextLabel {
                    Layout.fillWidth: true
                    visible: root.isIos
                    text: qsTrc("appshell/about", "CantoForge is an independent, unofficial iPadOS port of MuseScore Studio. It is not affiliated with or endorsed by MuseScore or Muse Group.")
                    wrapMode: Text.WordWrap
                }

                Column {
                    spacing: 8
                    Layout.fillWidth: true

                    StyledTextLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.isIos ? qsTrc("appshell/about", "Based on MuseScore Studio %1").arg(aboutModel.upstreamVersion())
                                         : qsTrc("appshell/about", "Version:") + " " + aboutModel.museScoreVersion()
                        font: ui.theme.bodyBoldFont
                    }

                    StyledTextLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.isIos
                        text: qsTrc("appshell/about", "iPad app build: %1").arg(aboutModel.portBuildVersion())
                    }

                    Row {
                        spacing: 4
                        anchors.horizontalCenter: parent.horizontalCenter

                        StyledTextLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (root.isIos ? qsTrc("appshell/about", "Source base revision:")
                                              : qsTrc("appshell/about", "Revision:")) + " " + aboutModel.museScoreRevision()
                        }

                        FlatButton {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: IconCode.COPY

                            onClicked: {
                                aboutModel.copyRevisionToClipboard()
                            }
                        }
                    }
                }

                StyledTextLabel {
                    Layout.fillWidth: true
                    text: {
                        if (root.isIos) {
                            return qsTrc("appshell/about", "Project source, releases and issue reports: <a href=\"%1\">GitHub</a>.")
                                   .arg(aboutModel.portProjectUrl().url)
                        }

                        let museScoreUrl = aboutModel.museScoreUrl()

                        //: %1 will be a link to the MuseScore website
                        let line1 = qsTrc("appshell/about", "Visit %1 for new versions and more information.")
                                    .arg(`<a href="${museScoreUrl.url}">${museScoreUrl.displayName}</a>`)

                        let line2 = qsTrc("appshell/about", "Get <a href=\"%1\">help</a> with the program or <a href=\"%2\">contribute</a> to its development.")
                                    .arg(aboutModel.museScoreForumUrl().url)
                                    .arg(aboutModel.museScoreContributionUrl().url)

                        return line1 + "<br>" + line2
                    }
                    wrapMode: Text.WordWrap
                    maximumLineCount: root.isIos ? 100 : 3
                }

                StyledTextLabel {
                    Layout.fillWidth: true
                    visible: root.isIos
                    text: qsTrc("appshell/about", "The MuseScore <a href=\"%1\">website</a> and <a href=\"%2\">forum</a> are upstream resources. Report iPad port issues to the CantoForge project.")
                          .arg(aboutModel.museScoreUrl().url)
                          .arg(aboutModel.museScoreForumUrl().url)
                    wrapMode: Text.WordWrap
                }

                StyledTextLabel {
                    Layout.fillWidth: true

                    text: root.isIos
                          ? qsTrc("appshell/about", "CantoForge stores scores and diagnostic logs on your device. Online tutorials and external websites use network connections and are subject to their providers’ privacy policies.")
                          : qsTrc("appshell/about", "For privacy information, see our <a href=\"%1\">privacy policy</a>.")
                            .arg(aboutModel.museScorePrivacyPolicyUrl().url)

                    wrapMode: Text.WordWrap
                    maximumLineCount: root.isIos ? 100 : 3
                }

                StyledTextLabel {
                    Layout.fillWidth: true
                    text: qsTrc("appshell/about", "Copyright © 1999-2026 MuseScore Limited and others.\nPublished under the <a href=\"%1\">GNU General Public License version 3</a>.")
                          .arg("https://www.gnu.org/licenses/gpl-3.0.html")
                          .replace("\n", "<br>")

                    wrapMode: Text.WordWrap
                    maximumLineCount: root.isIos ? 100 : 3
                }

                StyledTextLabel {
                    Layout.fillWidth: true
                    visible: root.isIos
                    text: qsTrc("appshell/about", "iPadOS adaptations: CantoForge contributors. Third-party libraries, fonts and SoundFonts retain their own licenses and notices.")
                    wrapMode: Text.WordWrap
                }
            }
        }

        RowLayout {
            id: footer
            Layout.alignment: Qt.AlignRight
            Layout.rightMargin: 16
            Layout.bottomMargin: 16

            spacing: 12

            FlatButton {
                text: qsTrc("global", "OK")

                onClicked: {
                    root.hide()
                }
            }
        }
    }
}
