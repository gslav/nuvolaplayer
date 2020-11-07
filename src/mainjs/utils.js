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

/**
 * Replaces placeholders in a template string with provided data.
 *
 * Placeholders are in form of ``{n}`` where ``n`` is index of data argument starting at 1.
 * Special placeholders are ``{-1}`` for ``{`` and ``{-2}`` for ``}``.
 *
 * @param String template    template string
 * @param Variant data...    other arguments will be used as data for replacement
 * @return String
 *
 * ```js
 * alert(Nuvola.format('My name is {2}. {1} {2}!', 'James', 'Bond'))
 * // 'My name is Bond. James Bond!'
 *
 * // You can create an alias
 * var $fmt = Nuvola.format;
 * alert($fmt('My name is {2}. {1} {2}!', 'James', 'Bond'))
 * ```
 */
Nuvola.format = function () {
  const args = arguments
  return args[0].replace(Nuvola.format._regex, function (item) {
    const index = parseInt(item.substring(1, item.length - 1))
    if (index > 0) { return typeof args[index] !== 'undefined' ? args[index] : '' } else if (index === -1) { return '{' } else if (index === -2) { return '}' }
    return ''
  })
}

Nuvola.formatVersion = function (encodedVersion) {
  const micro = encodedVersion % 100
  encodedVersion = (encodedVersion - micro) / 100
  const minor = encodedVersion % 100
  const major = (encodedVersion - minor) / 100
  return major + '.' + minor + '.' + micro
}

Nuvola.format._regex = /{-?[0-9]+}/g

Nuvola.inArray = function (array, item) {
  return array.indexOf(item) > -1
}

/**
 * Triggers mouse event on element
 *
 * @since API 4.5: x, y coordinates were added.
 *
 * @param HTMLElement elm    Element object
 * @param String name        Event name
 * @param Number x           Relative x position within the element 0.0..1.0 (default 0.5)
 * @param Number y           Relative y position within the element 0.0..1.0 (default 0.5)
 */
Nuvola.triggerMouseEvent = function (elm, name, x, y) {
  const rect = elm.getBoundingClientRect()
  const width = rect.width * (x === undefined ? 0.5 : x)
  const height = rect.height * (y === undefined ? 0.5 : y)
  const opts = {
    view: document.defaultView,
    bubbles: true,
    cancelable: true,
    button: 0,
    relatedTarget: elm
  }
  opts.clientX = rect.left + width
  opts.clientY = rect.top + height
  opts.screenX = window.screenX + opts.clientX
  opts.screenY = window.screenY + opts.clientY
  const event = new window.MouseEvent(name, opts)
  elm.dispatchEvent(event)
}

/**
 * Simulates click on element
 *
 * @since API 4.5: x, y coordinates were added.
 *
 * @param HTMLElement elm    Element object
 * @param Number x           Relative x position within the element 0.0..1.0 (default 0.5)
 * @param Number y           Relative y position within the element 0.0..1.0 (default 0.5)
 */
Nuvola.clickOnElement = function (elm, x, y) {
  Nuvola.triggerMouseEvent(elm, 'mouseover', x, y)
  Nuvola.triggerMouseEvent(elm, 'mousedown', x, y)
  Nuvola.triggerMouseEvent(elm, 'mouseup', x, y)
  Nuvola.triggerMouseEvent(elm, 'click', x, y)
  Nuvola.triggerMouseEvent(elm, 'mouseout', x, y)
}

/**
 * Simulates input and change event
 *
 * @since API 4.11
 * @since API 4.12: The change event is emitted as well.
 *
 * @param HTMLInputElement elm    Input element object
 * @param Var value               The value to set
 */
Nuvola.setInputValueWithEvent = function (elm, value) {
  elm.value = value
  elm.dispatchEvent(new window.Event('input', { bubbles: true, cancelable: true }))
  elm.dispatchEvent(new window.Event('change', { bubbles: true, cancelable: true }))
}

/**
 * Creates HTML text node
 *
 * @param String text    text of the node
 * @return    new text node
 */
Nuvola.makeText = function (text) {
  return document.createTextNode(text)
}

/**
 * Creates HTML element
 *
 * @param String name          element name
 * @param Object attributes    element attributes (optional)
 * @param String text          text of the element (optional)
 * @return new HTML element
 */
Nuvola.makeElement = function (name, attributes, text) {
  const elm = document.createElement(name)
  attributes = attributes || {}
  for (const key in attributes) { elm.setAttribute(key, attributes[key]) }

  if (text !== undefined && text !== null) { elm.appendChild(Nuvola.makeText(text)) }

  return elm
}

/**
 * Compares own properties of two objects
 *
 * @param Object object1    the first object to compare
 * @param Object object2    the second object to compare
 * @return Array of names of different properties
 */
Nuvola.objectDiff = function (object1, object2) {
  const changes = []
  for (const property in object1) {
    if (Object.prototype.hasOwnProperty.call(object1, property) &&
        (!Object.prototype.hasOwnProperty.call(object2, property) || object1[property] !== object2[property])) { changes.push(property) }
  }

  return changes
}

/**
 * Parse time as number of microseconds
 *
 * @param String time    time expression `HH:MM:SS'
 * @return the time in microseconds
 */
Nuvola.parseTimeUsec = function (time) {
  if (!time) { return 0 }
  if (time * 1 === time) { return time }
  const parts = time.split(':')
  const sign = parts[0] * 1 < 0 ? -1 : 1
  let seconds = 0
  let item = parts.pop()
  if (item !== undefined) {
    seconds = Math.abs(1 * item)
    item = parts.pop()
    if (item !== undefined) {
      seconds += Math.abs(60 * item)
      item = parts.pop()
      if (item !== undefined) { seconds += Math.abs(60 * 60 * item) }
    }
  }
  return !isNaN(seconds) ? sign * seconds * 1000 * 1000 : 0
}

/**
 * Encode version info as a single number
 *
 * @since API 4.5
 *
 * @param Number major    major version
 * @param Number minor    minor version
 * @param Number micro    micro version
 * @return encoded version number
 */
Nuvola.encodeVersion = function (major, minor, micro) {
  return (major || 0) * 100000 + (minor || 0) * 1000 + (micro || 0)
}

/**
 * Check sufficient Nuvola's version
 *
 * @since API 4.5
 *
 * @param Number major    major version
 * @param Number minor    minor version
 * @param Number micro    micro version
 * @return true if Nuvola's version is greater than or equal to the required version
 *
 * ```js
 * if (Nuvola.checkVersion && Nuvola.checkVersion(4, 5)) {
 *   // Safe to use API >= 4.5
 * }
 * ```
 */
Nuvola.checkVersion = function (major, minor, micro) {
  const v1 = Nuvola.encodeVersion(major, minor, micro)
  const v2 = Nuvola.encodeVersion(Nuvola.VERSION_MAJOR, Nuvola.VERSION_MINOR, Nuvola.VERSION_MICRO)
  return v2 >= v1
}

/**
 * Query element and return text content or null.
 *
 * @since API 4.11
 * @since API 4.12: You can specify a parent element and a relative selector as an array of [parent element, selector].
 * @param String|Array selector     CSS selector for element or an array containing [parent element, selector].
 * @param Function func             Optional function to modify resulting text.
 * @return Text content of the element, possibly modified with func, null if element is not found.
 */
Nuvola.queryText = function (selector, func) {
  let parent = document
  if (Array.isArray(selector)) {
    parent = selector[0]
    selector = selector[1]
  }
  if (!parent) {
    return null
  }
  const elm = parent.querySelector(selector)
  const value = elm ? elm.textContent.trim() || null : null
  return (value && func) ? func(value, elm) : value
}

/**
 * Query element and return its attribute or null.
 *
 * @since API 4.11
 * @since API 4.12: You can specify a parent element and a relative selector as an array of [parent element, selector].
 * @param String|Array selector     CSS selector for element or an array containing [parent element, selector].
 * @param String attribute          Attribute name.
 * @param Function func             Optional function to modify resulting value.
 * @return The attribute of the element, possibly modified with func, null if element is not found.
 */
Nuvola.queryAttribute = function (selector, attribute, func) {
  let parent = document
  if (Array.isArray(selector)) {
    parent = selector[0]
    selector = selector[1]
  }
  if (!parent) {
    return null
  }
  const elm = parent.querySelector(selector)
  if (!elm) {
    return null
  }
  const value = elm.getAttribute(attribute)
  return func ? func(value, elm) : value
}

/**
 * Download image and export it as base64 data-URI
 *
 * @since API 4.11
 * @param String url         The image URL
 * @param Function callback    The function to be called when the image is exported. The first argument is null
 *     if any error occurred, base64 data-URI otgerwise.
 */
Nuvola.exportImageAsBase64 = function (url, callback) {
  const img = new window.Image()
  img.onload = function () {
    let canvas = document.createElement('canvas')
    const ctx = canvas.getContext('2d')
    canvas.height = img.height
    canvas.width = img.width
    ctx.drawImage(img, 0, 0)
    callback(canvas.toDataURL('image/jpeg', 0.95))
    canvas = null
    this.onerror = null
    this.onload = null
    this.src = ''
  }
  img.onerror = function () {
    callback(null)
    this.onload = null
    this.error = null
    this.src = ''
  }
  img.src = url
}
