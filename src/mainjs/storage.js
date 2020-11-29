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
require('signals')
require('async')

/**
 * Prototype object to hold key-value mapping
 */
const KeyValueStorage = Nuvola.$prototype(null)

/**
 * Initializes new key-value storage
 *
 * @param Number index    index in storage pool
 */
KeyValueStorage.$init = function (index) {
  this.index = index
}

/**
 * Set default value for given key
 *
 * This function should be called only once per key, for example in @link{Core::InitAppRunner} handler.
 *
 * @deprecated Nuvola 4.8: Use async variant instead.
 * @param String key       the key name
 * @param Variant value    value of the key
 *
 * ```
 * WebApp._onInitAppRunner = function (emitter) {
 *   Nuvola.WebApp._onInitAppRunner.call(this, emitter)
 *
 *   var ADDRESS = 'app.address'
 *   // Nuvola.config is a KeyValueStorage
 *   Nuvola.config.setDefault(ADDRESS, 'default')
 * }
 * ```
 */
KeyValueStorage.setDefault = function (key, value) {
  Nuvola._keyValueStorageSetDefaultValue(this.index, key, value)
}

/**
 * Set default value for given key
 *
 * This function should be called only once per key, for example in @link{Core::InitAppRunner} handler.
 *
 * @since Nuvola 4.8
 * @async
 * @param String key       the key name
 * @param Variant value    value of the key
 *
 * ```
 * WebApp._onInitAppRunner = function(emitter) {
 *   Nuvola.WebApp._onInitAppRunner.call(this, emitter)
 *
 *   var ADDRESS = 'app.address'
 *   // Nuvola.config is a KeyValueStorage
 *   Nuvola.config.setDefaultAsync(ADDRESS, 'default').catch(console.log.bind(console))
 * }
 * ```
 */
KeyValueStorage.setDefaultAsync = function (key, value) {
  return Nuvola.Async.begin((ctx) => Nuvola._keyValueStorageSetDefaultValueAsync(this.index, key, value, ctx.id))
}

/**
 * Check whether the storage has given key
 *
 * @deprecated Nuvola 4.8: Use async variant instead.
 * @param String key    storage key name
 * @return ``false`` if the storage doesn't contain value for the key
 *     (even if @link{KeyValueStorage.setDefault|default value has been set}),
 *     ``true`` otherwise
 */
KeyValueStorage.hasKey = function (key) {
  return Nuvola._keyValueStorageHasKey(this.index, key)
}

/**
 * Check whether the storage has given key
 *
 * @since Nuvola 4.8
 * @async
 * @param String key    storage key name
 * @return ``false`` if the storage doesn't contain value for the key
 *     (even if @link{KeyValueStorage.setDefault|default value has been set}),
 *     ``true`` otherwise
 */
KeyValueStorage.hasKeyAsync = function (key) {
  return Nuvola.Async.begin((ctx) => Nuvola._keyValueStorageHasKeyAsync(this.index, key, ctx.id))
}

/**
 * Get value by key name
 *
 * Note that behavior on a key without an assigned value nor @link{KeyValueStorage.setDefault|the default value}
 * is undefined - it may return *anything* or throw and error. (The current implementation returns string ``'<UNDEFINED>'``
 * as it helps to identify unwanted manipulation with ``undefined`` value type.)
 *
 * @deprecated Nuvola 4.8: Use async variant instead.
 * @param String key    key name
 * @return value set by @link{KeyValueStorage.set} or @link{KeyValueStorage.setDefault} for given key
 */
KeyValueStorage.get = function (key) {
  return Nuvola._keyValueStorageGetValue(this.index, key)
}

/**
 * Get value by key name
 *
 * Note that behavior on a key without an assigned value nor @link{KeyValueStorage.setDefault|the default value}
 * is undefined - it may return *anything* or throw and error. (The current implementation returns string ``'<UNDEFINED>'``
 * as it helps to identify unwanted manipulation with ``undefined`` value type.)
 *
 * @since Nuvola 4.8
 * @async
 * @param String key    key name
 * @return value set by @link{KeyValueStorage.set} or @link{KeyValueStorage.setDefault} for given key
 */
KeyValueStorage.getAsync = function (key) {
  return Nuvola.Async.begin((ctx) => Nuvola._keyValueStorageGetValueAsync(this.index, key, ctx.id))
}

/**
 * Set value for given key
 *
 * @deprecated Nuvola 4.8: Use async variant instead.
 * @param String key       key name
 * @param Variant value    value of given key
 */
KeyValueStorage.set = function (key, value) {
  if (Object.prototype.toString.call(value) === '[object Object]') {
    throw new Error('Key-value storage is for primitive types only. It is not yet possible to store objects.')
  }
  Nuvola._keyValueStorageSetValue(this.index, key, value)
}

/**
 * Set value for given key
 *
 * @since Nuvola 4.8
 * @async
 * @param String key       key name
 * @param Variant value    value of given key
 */
KeyValueStorage.setAsync = function (key, value) {
  return Nuvola.Async.begin((ctx) => {
    if (Object.prototype.toString.call(value) === '[object Object]') {
      throw new Error('Key-value storage is for primitive types only. It is not yet possible to store objects.')
    } else {
      Nuvola._keyValueStorageSetValueAsync(this.index, key, value, ctx.id)
    }
  })
}

/**
 * Prototype object to access persistent configuration
 *
 * Note: Use @link{SessionStorage} for temporary data.
 */
const ConfigStorage = Nuvola.$prototype(KeyValueStorage, Nuvola.SignalsMixin)

/**
 * Initializes new ConfigStorage object
 */
ConfigStorage.$init = function () {
  KeyValueStorage.$init.call(this, 0)

  /**
   * Emitted when a configuration key is changed
   *
   * @param String key    key name
   */
  this.addSignal('ConfigChanged')
}

/**
 * Prototype object of a key-value storage with a lifetime limited to the current session
 *
 * Note: Use @link{SessionStorage} to store persistent data.
 */
const SessionStorage = Nuvola.$prototype(KeyValueStorage)

/**
 * Initializes new SessionStorage object.
 */
SessionStorage.$init = function () {
  KeyValueStorage.$init.call(this, 1)
}

// export public items
Nuvola.KeyValueStorage = KeyValueStorage
Nuvola.ConfigStorage = ConfigStorage
Nuvola.SessionStorage = SessionStorage

/**
 * Instance object of @link{SessionStorage} prototype connected to Nuvola backend.
 */
Nuvola.session = Nuvola.$object(SessionStorage)

/**
 * Instance object of @link{ConfigStorage} prototype connected to Nuvola backend.
 */
Nuvola.config = Nuvola.$object(ConfigStorage)
