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
require('async')

/**
 * Desktop notification.
 */
const Notification = Nuvola.$prototype(null)

/**
 * Creates new named notification.
 *
 * @param String  name                notification name (identifier)
 * @param Boolean resident            mark the notification as resident by default
 * @param optional String category    category of a notification
 */
Notification.$init = function (name, resident, category) {
  this.name = name
  this.resident = !!resident
  this.category = category || ''
}

/**
 * Update properties of a notification
 *
 * @param String title        short title
 * @param String text         text of the notification
 * @param String? iconName    name of icon for notification
 * @param String? iconPath    path to an icon for notification
 * @param Boolean resident    mark the notification as resident, use null/undefined to reuse last value
 */
Notification.update = function (title, text, iconName, iconPath, resident) {
  if (resident == null) { resident = this.resident } else { this.resident = !!resident }

  Nuvola._callIpcMethodVoid('/nuvola/notification/update',
    [this.name, title, text, iconName || '', iconPath || '', !!resident, this.category])
}

/**
 * Set actions available as buttons in notification.
 *
 * @param String[] actions    array of action names
 */
Notification.setActions = function (actions) {
  Nuvola._callIpcMethodVoid('/nuvola/notification/set-actions', [this.name, actions])
}

/**
 * Remove all actions available as buttons in notification.
 */
Notification.removeActions = function () {
  Nuvola._callIpcMethodVoid('/nuvola/notification/remove-actions', [this.name])
}

/**
 * Shows notification.
 *
 * @param force    ensure notification is shown if true, otherwise show it when suitable
 */
Notification.show = function (force) {
  Nuvola._callIpcMethodVoid('/nuvola/notification/show', [this.name, !!force])
}

/**
 * Manages desktop notifications.
 */
const Notifications = Nuvola.$prototype(null)

/**
 * Convenience method to creates new named notification.
 *
 * @param String  name                notification name (identifier)
 * @param Boolean resident            mark the notification as resident by default
 * @param optional String category    category of a notification
 */
Notifications.getNamedNotification = function (name, resident, category) {
  return Nuvola.$object(Notification, name, resident, category)
}

/**
 * Check whether persistence is supported
 *
 * @deprecated Nuvola 4.8: Use async variant instead.
 * @return Boolean true if persistence is supported
 */
Notifications.isPersistenceSupported = function () {
  Nuvola.log('Notifications.isPersistenceSupported is deprecated since Nuvola 4.8. Use async variant instead.')
  return Nuvola._callIpcMethodSync('/nuvola/notifications/is-persistence-supported')
}

/**
 * Check whether persistence is supported
 *
 * @since Nuvola 4.8
 * @async
 * @return Boolean true if persistence is supported
 */
Notifications.isPersistenceSupportedAsync = function () {
  return Nuvola.Async.call('/nuvola/notifications/is-persistence-supported')
}

/**
 * Instantly show anonymous notification.
 *
 * @param String title        short title
 * @param String text         text of the notification
 * @param String? iconName    name of icon for notification
 * @param String? iconPath    path to an icon for notification
 * @param Boolean force       ensure notification is shown if true, otherwise show it when suitable
 * @param optional String category    category of a notification
 */
Notifications.showNotification = function (title, text, iconName, iconPath, force, category) {
  Nuvola._callIpcMethodVoid('/nuvola/notifications/show-notification',
    [title, text || '', iconName || '', iconPath || '', !!force, category || ''])
}

// export public items
Nuvola.Notification = Notification
Nuvola.Notifications = Notifications
Nuvola.notifications = Nuvola.$object(Notifications)
