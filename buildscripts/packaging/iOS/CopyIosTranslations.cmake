# SPDX-License-Identifier: GPL-3.0-only
file(GLOB translations "${TRANSLATION_DIR}/*.qm")
# qt_<language>.qm is a catalog with dependencies (including qtdeclarative),
# not a standalone translation. Include the corresponding module catalogs.
file(GLOB qt_translations "${QT_TRANSLATION_DIR}/*.qm")
if(NOT translations)
    message(FATAL_ERROR "No Studio translations found in ${TRANSLATION_DIR}")
endif()
file(INSTALL ${translations} ${qt_translations} DESTINATION "${APP_BUNDLE}/locale")
