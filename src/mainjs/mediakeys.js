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

/**
 * @enum Identifiers of media keys
 */
const MediaKey = {
  /**
   * Play key
   */
  PLAY: 'Play',
  /**
   * Pause key
   */
  PAUSE: 'Pause',
  /**
   * Stop key
   */
  STOP: 'Stop',
  /**
   * Go to the previous track key
   */
  PREV: 'Previous',
  /**
   * Go to the next track key
   */
  NEXT: 'Next'
}

/**
 * Prototype object integrating media keys handling
 */
const MediaKeys = Nuvola.$prototype(null, Nuvola.SignalsMixin)

/**
 * Initializes new MediaKeys object.
 */
MediaKeys.$init = function () {
  /**
   * Emitted when a media key is pressed.
   *
   * @param MediaKey key    the pressed key
   */
  this.addSignal('MediaKeyPressed')
}

// export public items
Nuvola.MediaKey = MediaKey
Nuvola.MediaKeys = MediaKeys

/**
 * Instance object of @link{MediaKeys} prototype connected to Nuvola backend.
 */
Nuvola.mediaKeys = Nuvola.$object(MediaKeys)
