/*
 * Copyright 2014-2019 Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

require('prototype')

/**
 * Manages launcher component (Unity dock item, tray icon, ...)
 */
const Launcher = Nuvola.$prototype(null)

/**
 * Set launcher tooltip.
 *
 * This functionality is currently implemented only by the tray icon.
 *
 * @param String tooltip    short tooltip text
 */
Launcher.setTooltip = function (tooltip) {
  Nuvola._callIpcMethodVoid('/nuvola/launcher/set-tooltip', [tooltip || ''])
}

/**
 * Set launcher menu actions.
 *
 * This functionality has two implementations:
 *
 *  -  menu of a tray icon
 *  -  menu of a Unity dock item
 *
 * @param "Array of String" actions    action names
 */
Launcher.setActions = function (actions) {
  Nuvola._callIpcMethodVoid('/nuvola/launcher/set-actions', [actions])
}

/**
 * Removes all launcher menu actions.
 */
Launcher.removeActions = function () {
  Nuvola._callIpcMethodVoid('/nuvola/launcher/remove-actions')
}

/**
 * Add action to launcher's menu.
 *
 * @param String action    action name
 */
Launcher.addAction = function (action) {
  Nuvola._callIpcMethodVoid('/nuvola/launcher/add-action', [action])
}

/**
 * Remove action from launcher's menu.
 *
 * @param String action    action name
 */
Launcher.removeAction = function (action) {
  Nuvola._callIpcMethodVoid('/nuvola/launcher/remove-action', [action])
}

// export public items
Nuvola.Launcher = Launcher

/**
 * Instance object of @link{Launcher} prototype connected to Nuvola backend.
 */
Nuvola.launcher = Nuvola.$object(Launcher)
