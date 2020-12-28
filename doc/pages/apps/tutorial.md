Title: Service Integrations Tutorial

[TOC]

This tutorial briefly describes creation of **a new web app script for Nuvola Apps Runtime from
scratch**. The goal is to write an integration script for *demo player website* shipped with
Nuvola SDK and to prepare you to create your own service integration.
I'm looking forward to a code review ;-)

Prepare development environment
===============================

 1. Install [Nuvola App Developer Kit (ADK)](https://github.com/tiliado/nuvolaruntime/wiki/Nuvola-App-Developer-Kit).
    This is a flatpak runtime that contains Nuvola Apps Runtime, SDK and dependencies.

 2. Create a project directory `~/projects/nuvola-apps` (or any other name, but don't forget to
    adjust paths in this tutorial).

        mkdir -p ~/projects/nuvola-apps

 3. [Launch and set up Nuvola ADK](https://github.com/tiliado/nuvolaruntime/wiki/Nuvola-App-Developer-Kit#running-and-set-up)

 4. Create a new project with "nuvola://demo/main.html" as a home URL.

        $ cd ~/projects/nuvola-apps
        $ nuvolasdk new-project --name "Happy Songs" --url "nuvola://demo/main.html"
        ...
        Finished!

        ./nuvola-app-happy-songs
        total 52
        drwxr-sr-x 1 fenryxo fenryxo   244 Dec  4 18:39 .
        drwxr-xr-x 1 fenryxo fenryxo    44 Dec  4 18:39 ..
        -rw-r--r-- 1 fenryxo fenryxo   103 Dec  4 18:39 CHANGELOG.md
        -rwxr-xr-x 1 fenryxo fenryxo    65 Dec  4 18:39 configure
        -rw-r--r-- 1 fenryxo fenryxo  3649 Dec  4 18:39 CONTRIBUTING.md
        drwxr-sr-x 1 fenryxo fenryxo   144 Dec  4 18:39 .git
        -rw-r--r-- 1 fenryxo fenryxo    91 Dec  4 18:39 .gitignore
        -rw-r--r-- 1 fenryxo fenryxo  2701 Dec  4 18:39 integrate.js
        -rw-r--r-- 1 fenryxo fenryxo  1246 Dec  3 18:57 LICENSE-BSD.txt
        -rw-r--r-- 1 fenryxo fenryxo 18424 Dec  3 18:57 LICENSE-CC-BY.txt
        -rw-r--r-- 1 fenryxo fenryxo   541 Dec  4 18:39 metadata.in.json
        -rw-r--r-- 1 fenryxo fenryxo  1079 Dec  4 18:39 README.md
        drwxr-sr-x 1 fenryxo fenryxo    60 Dec  3 18:57 src

 5. Copy a demo player - an example of a streaming website.

        :::sh
        cd ~/projects/nuvola-apps/nuvola-app-happy-songs
        cp -r "$(nuvolasdk data-dir)/demo/demo" .

 6. If you are not familiar with the [Git version control system][git],
    check [Git tutorial](https://try.github.io/levels/1/challenges/1)
    or [Pro Git Book](http://git-scm.com/book).

Metadata file
=============

**Metadata file contains basic information about your service integrations.** It uses
[JSON format](http://en.wikipedia.org/wiki/JSON) and it's called ``metadata.in.json``.
Let's look at the example:

    :::json
    {
      "id": "happy_songs",
      "name": "Happy Songs",
      "maintainer_name": "Jiří Janoušek",
      "maintainer_link": "https://github.com/fenryxo",
      "version_major": 1,
      "version_minor": 0,
      "api_major": 4,
      "api_minor": 6,
      "categories": "AudioVideo;Audio;",
      "requirements": "Chromium[65] Codec[MP3] Feature[MSE]",
      "home_url": "nuvola://demo/main.html",
      "license": "2-Clause BSD, CC-BY-3.0",
      "build": {
        "icons": [
          "src/icon.svg SCALABLE 64 128 256",
          "src/icon-xs.svg 16 22 24",
          "src/icon-sm.svg 32 48"
        ]
      }

This file contains several mandatory fields:

`id`

:   Identifier of the service. It can contain only letters `a-z`, digits `0-9` and underscore `_` to
    separate words, e.g. `google_play_music` for Google Play Music, `8tracks` for 8tracks.com.

`name`

:   Name of the service (for humans), e.g. "Google Play Music".

`version_major`

:   Major version of the integration, must be an integer > 0. You should use
    `1` for an initial version. This number is increased, when a major change occurs.

`version_minor`

:   A minor version of service integration, an integer >= 0.  This field should
    be increased only when a new release is made. Never increase version number
    in regular commits nor pull requests, but only in release commits with
    a commit message "Release X.Y".

`maintainer_name`

:   A name of the maintainer of the service integration.

`maintainer_link`

:   A link to a page with contact to maintainer (including `http://` or `https://`) or an email
    address prefixed by `mailto:`.

`api_major` and `api_minor`

:   A required version of Nuvola Runtime API. You should use API >= 4.6. You should update API version only
    if your script doesn't work with older API. For example, if Nuvola Runtime adds a new feature
    into API 4.X that is so essential for your script that it cannot function properly without it,
    you will increase API requirement to 4.X. However, all Nuvola versions with API less
    then 4.x won't be able to load your script any more.

``categories``

:   [Application categories](http://standards.freedesktop.org/menu-spec/latest/apa.html) suitable
    for the web app. It is used to place a desktop launcher to proper category in applications menu.
    Media player services should be in ``"AudioVideo;Audio;"``.

`home_url`

:   Home page of your service. The dump example of a streaming website contains file `demo/main.html`, which
    has a special address `nuvola://demo/main.html`. You will use a real homepage later in your own
    service integration (e.g. `https://play.google.com/music/` for Google Play Music).

    This field is not required if you use custom function to handle home page request.
    See [Web apps with a variable home page URL](:apps/variable-home-page-url.html).

`license`

:   List of licenses that apply to your script, e.g. `"2-Clause BSD, CC-BY-3.0"`.

`requirements`

:   If your streaming service requires **Flash plugin** or **HTML5 Audio support** for playback
    (very likely), you need to [add respective web app requirement flags for Nuvola 4.x+](#web-technologies).

`build`

:   Instructions for the build system of Nuvola SDK. It contains a list of `icons` and their sizes to generate and
    an optional list of `extra_data` containing filenames to include during installation.

This file can include also optional fields:

`window_width`, `window_height`

:   Suggested window width or height in pixels.

`allow_insecure_content` (since Nuvola 3.1)

:   Whether the page served over the secure HTTPS protocol depends on insecure content served over the HTTP protocol.
    As a rule of thumb, set `allow_insecure_content` to `true` if you see console warnings similar to that of Pocket Casts:
    `Runner: **CONSOLE WARN [blocked]** The page at https://play.pocketcasts.com/web **was not allowed** to display
    insecure content from http://media.scpr.org/.` The default value is `false`.

`user_agent` (since Nuvola 4.4)
:   It can sometimes happen that a web page provides a different code depending on which web browser is used.
    Nuvola uses the user agent of WebKitGTK web rendering engine by default. However, if the web app you are
    writing script for doesn't work with it, you can [disguise Nuvola as a different browser](#user-agent-quirks).

!!! danger "Extra rules for metadata.in.json"
    If you want to have your integration script maintained and distributed as a part of the Nuvola
    Apps project, you have to follow rules in [Service Integrations Guidelines](:apps/guidelines.html).

Integration script
==================

**The integration script is the fundamental part of the service integration.** It's written in
JavaScript and called ``integrate.js``. This script is called once at start-up of the web app to
perform initialization of the main process and again
in the web page rendering process every-time a web page is loaded in the web view. Let's look at the
next sample integration script that doesn't actually do much, but will be used as a base for further
modifications.

```
#!js
/*
 * Copyright 2018 Your name <your e-mail>
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

'use strict'

(function (Nuvola) {

  // Create media player component
  var player = Nuvola.$object(Nuvola.MediaPlayer)

  // Handy aliases
  var PlaybackState = Nuvola.PlaybackState
  var PlayerAction = Nuvola.PlayerAction

  // Create new WebApp prototype
  var WebApp = Nuvola.$WebApp()

  // Initialization routines
  WebApp._onInitWebWorker = function (emitter) {
    Nuvola.WebApp._onInitWebWorker.call(this, emitter)

    var state = document.readyState
    if (state === 'interactive' || state === 'complete') {
      this._onPageReady()
    } else {
      document.addEventListener('DOMContentLoaded', this._onPageReady.bind(this))
    }
  }

  // Page is ready for magic
  WebApp._onPageReady = function () {
    // Connect handler for signal ActionActivated
    Nuvola.actions.connect('ActionActivated', this)

    // Start update routine
    this.update()
  }

  // Extract data from the web page
  WebApp.update = function () {
    var track = {
      title: null,
      artist: null,
      album: null,
      artLocation: null,
      rating: null
    }

    player.setTrack(track)
    player.setPlaybackState(PlaybackState.UNKNOWN)

    // Schedule the next update
    setTimeout(this.update.bind(this), 500)
  }

  // Handler of playback actions
  WebApp._onActionActivated = function (emitter, name, param) {
  }

  WebApp.start();

})(this)  // function (Nuvola)
```

Lines 2-22

:   Copyright and license information. While you can choose any license for your work, it's
    recommended to use the license of Nuvola Apps Runtime as shown in the example.

Line 25

:   Use [strict JavaScript mode][JS_STRICT] in your scripts.

Lines 27 and 83

:   Use [self-executing anonymous function][JS_SEAF] to create closure with [Nuvola object](apiref>).
    (Integration script are executed with ``Nuvola`` object bound to ``this``).

Line 30

:   Create [MediaPlayer](apiref>Nuvola.MediaPlayer) component that adds playback actions and is later used to provide playback
    details.

Line 37

:   Create new WebApp prototype object derived from the [Nuvola.WebApp](apiref>Nuvola.WebApp) prototype that contains
    handy default handlers for initialization routines and signals from Nuvola core.
    You can override them if your web app requires more magic ;-)

Lines 40-49

:   Handler for [Nuvola.Core::InitWebWorker signal](apiref>Core%3A%3AInitWebWorker) signal that
    emitted in clear JavaScript environment with a brand new global ``window`` object. You should
    not touch it, only perform necessary initialization (usually not needed) and set your listener
    for either `document`'s `DOMContentLoaded` event (preferred) or `window`'s `load` event.

Lines 52-58

:   When document object model of a web page is ready, we register a signal handler for playback
    actions and call update() method.

Lines 61-75

:   The update() method periodically extracts playback state and track details.

Lines 78-79

:   Actions handler is used to respond to player actions.

Line 81

:   Convenience method to create and register new instance of your web app integration.

App Runner and Web Worker
=========================

Nuvola Apps Runtime uses two processes for each service (web app):

  * **App Runner process** that manages user interface, desktop integration components and
    a life-cycle of the WebKitGtk WebView. On start-up, Nuvola Runtime executes once the integration
    script in the App Runner process to perform initialization of the web app. Note that the script
    is executed in a **bare JavaScript environment**, which means there are no `window`, `document`
    or other common object provided by a web browser engine. Therefore, make sure you don't use any of these
    objects in your top-level code.

    In **the previous example**, there is not any handler for the
    [Nuvola.Core::InitAppRunner signal](apiref>Nuvola.Core::InitAppRunner).
    It usually is used only for extra features such as
    [Web apps with a variable home page URL]({filename}apps/variable-home-page-url.md),
    [Initialization and Preferences Forms]({filename}apps/initialization-and-preferences-forms.md)
    or [Custom Actions]({filename}apps/custom-actions.md).


  * **Web Worker process** is created by WebKitGtk WebView and it's the place where the web
    interface of a web app lives, i.e. where the website is loaded. Nuvola Runtime executes the
    integration script in the Web Worker process everytime a web page is loaded in it to integrate
    the web page. The script is executed in a complete WebKit JavaScript environment with all bells
    and whistles.

Check, Build and Run Your Script
================================

First of all, make sure you have upgraded to the latest
[Nuvola App Developer Kit (ADK)](https://github.com/tiliado/nuvolaruntime/wiki/Nuvola-App-Developer-Kit)
because it is updated between Nuvola releases. I always recommend running
`flatpak update --system; flatpak update --user` before doing any work.

Then run `nuvolasdk check-project` (inside Nuvola ADK environment) to check there are no common errors.

```
$ nuvolasdk check-project
Checking the project...
No errors have been found.
```

Finally, execute following commands:

  * `./configure` to generate `Makefile` and `metadata.json` from `metadata.in.json`
  * `make all` to build the project

After the project have been built, you can run your script with Nuvola Runtime from terminal with following command.

    $ nuvolaruntime -D

First of all, show **developer's sidebar** (Gear menu → Show sidebar → select "Developer" in the right
sidebar), then enable **Web Inspector** (click Open Dev Tools button for Chromium-based backend or
right-click the web page anywhere and select "Inspect element" for WebKitGTK backend).

![Show sidebar - GNOME Shell](:images/guide/show_sidebar_gnome_shell.png)

![Open Dev tools in CHromium](:images/guide/open_dev_tools.png)

![Inspect element in WebKitGTK](:images/guide/inspect_element.png)

Web Compatibility Issues
========================

Web Technologies
----------------

A particular web app may require certain technologies to function properly.
At present, Nuvola enables both Flash plugin and GStreamer HTML5 Audio by default.
However, this will change for Nuvola 4.x in the future and you should not count on it.

**Web app requirements** in Nuvola Apps Runtime 4.x are specified as the `requirements` property
in `metadata.in.json`. It can contain a space separated list of following requirements:

  * `Codec[MP3]`: The web app can play audio with HTML5 audio technology and requires a MP3 codec.
  * `Feature[Flash]`: The web app requires Adobe Flash plugin. Use only if your app cannot use
    HTML5 Audio.
  * `WebKitGTK[X.Y.Z]`: The web app requires WebKitGTK >= X.Y.Z.
  * `Chromium[X]`: The web app requires Chromium Embedded Framework from Chromium release X.
  * `Feature[MSE]`: The web app requires Media Source extension for HTML5 Audio playback.
  * `Codec[H264]`: The web app requires h264 codec for HTML5 Audio playback.

If you integrate **a media player**, start with `Chromium[65] Codec[MP3] Feature[MSE]`. If it complains about Flash plugin,
use `Chromium[65] Codec[MP3] Feature[MSE] Feature[Flash]`.

User Agent Quirks
-----------------

It can sometimes happen that a web page provides a different code depending on which web browser is used.
Nuvola uses the user agent of WebKitGTK web rendering engine by default. However, if the web app you are
writing script for doesn't work with it, you can disguise Nuvola as a different browser (this is known as
user agent quirks) by setting the `user_agent` attribute in `metadata.in.json`. There are several predefined
values (in order of preference):

  * `WEBKITGTK` or `WEBKITGTK nn`: The default user agent of WebKitGTK library. If no version number `nn` is provided,
    the latest known version is used.
  * `SAFARI` or `SAFARI nn`: The user agent of the Safari web browser, which also uses WebKit engine.
     If no version number `nn` is provided, the latest known version is used.
  * `CHROME` or `CHROME nn`: The user agent of the Google Chrome web browser, which uses the Blink engine
    originally based on WebKit. If no version number `nn` is provided, the latest known version is used.
  * `FIREFOX` or `FIREFOX nn`: The user agent of the Firefox web browser, which uses the Gecko engine
    originally based on WebKit. If no version number `nn` is provided, the latest known version is used.

Alternatively, you can provide a complete user agent string, e.g. `Mozilla/5.0 (Windows NT 10.0; Win64; x64)
AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.135 Safari/537.36 Edge/12.246` for Microsoft Edge
web browser.

Debugging and logging messages
==============================

You might want to print some debugging messages to console during development. There are two types
of them in Nuvola Apps Runtime:

  * **JavaScript console** is shown in the WebKit Web Inspector.
  * **Terminal console** is the black window with white text. Debugging messages are only printed
    if you have launched Nuvola Apps Runtime with ``-D`` or ``--debug`` flag.

The are two ways how to print debugging messages:

  * [Nuvola.log()](apiref>Nuvola.log) always prints only to terminal console.
  * [console.log()](https://developer.mozilla.org/en-US/docs/Web/API/console.log) prints to JavaScript
    console only if [Window object](https://developer.mozilla.org/en/docs/Web/API/Window) is
    the the global object of the current JavaScript environment. Otherwise, Nuvola.log is used as a
    fallback and a warning is issued.

You might be wondering **why the Window object isn't always available as the global JavaScript
object**. That's because Nuvola Runtime executes a lot of JavaScript code in a pure JavaScript
environment outside the web view. However, the [Core::InitWebWorker signal](apiref>Core%3A%3AInitWebWorker)
and your ``WebApp._onInitWebWorker`` and ``WebApp._onActionActivated`` signal handlers are
invoked in the web view with the global window object, so feel free to use ``console.log()``.


Integrate Web App
=================

After everything has been set up and the web page works correctly, we finally proceed to the main task: web app
integration. That means you script is supposed to extract data from a web page and pass them to Nuvola Apps Runtime
by calling [NuvolaKit JavaScript API](apiref>). There are two ways to extract data from a web page:

 1. Use [Document Object Model][DOM] to get information from the HTML code of the web page.
 2. Use JavaScript API provided by the web page if there is any.

[DOM]: https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model

The first way is more general and will be described here. The folowing methods are useful:

  * [document.getElementById](https://developer.mozilla.org/en-US/docs/Web/API/document.getElementById) -
    look-up an element by ``id`` attribute
  * [document.getElementsByName](https://developer.mozilla.org/en-US/docs/Web/API/Document.getElementsByName) -
    look-up elements by ``name`` attribute
  * [document.getElementsByClassName](https://developer.mozilla.org/en-US/docs/Web/API/document.getElementsByClassName) -
    look-up elements by ``class`` attribute
  * [document.getElementsByTagName](https://developer.mozilla.org/en-US/docs/Web/API/document.getElementsByTagName) -
    look-up elements by tag name (e.g. ``a``, ``div``, etc.)
  * [document.querySelector](https://developer.mozilla.org/en-US/docs/Web/API/document.querySelector) -
    look-up the first element that matches provided [CSS selector][B1]
  * [document.querySelectorAll](https://developer.mozilla.org/en-US/docs/Web/API/document.querySelectorAll) -
    look-up all elements that match provided [CSS selector][B1]

[B1]: https://developer.mozilla.org/en-US/docs/Web/Guide/CSS/Getting_Started/Selectors


Media Player Integration
------------------------

Historically, Nuvola Apps Runtime (previously known as Nuvola Player) has a great support for media players and
offers [a high level API for Media Player Integration](./mediaplayer.html).

Other web apps
-------------

Other web apps can use [NuvolaKit JavaScript API](apiref>) directly as there is no high level API for other kinds of web
apps yet.


Push your work upstream
=======================

If you would like to have your service integration **maintained as a part of Nuvola
Apps project** and distributed in Nuvola Player repository, follow these steps:

  * Make sure your script follows the [Service Integration Guidelines](:apps/guidelines.html).
  * Make sure your ``integrate.js`` contain proper copyright information
    "Copyright 2017 Your name &lt;your e-mail&gt;".
  * The test service used in tutorial and guide contains 2-Clause BSD license. If you have severe
    reasons to choose a different license, update license text in both ``integrate.js`` and
    ``LICENSE`` files.
  *  Create an empty remote repository named "nuvola-app-{app-id}" on GitHub.
     See [GitHub For Beginners: Don't Get Scared, Get Started][A1] for help.
  * Push content of your local repository to the remote repository.

        :::sh
        git remote add origin git@github.com:fenryxo/nuvola-app-test.git
        git push -u origin master

  * Create new issue in your repository titled "Push to Nuvola Apps project"
  * Create new issue at [Nuvola Apps Runtime repository](https://github.com/tiliado/nuvolapruntime/issues/new)
    with subject "Code review: You Service Name integration" and post a link the the issue created
    above.

[A1]: http://readwrite.com/2013/09/30/understanding-github-a-journey-for-beginners-part-1
[A2]: http://readwrite.com/2013/10/02/github-for-beginners-part-2

What to do next
===============

Supposing you have followed this tutorial, you have enough knowledge to create your own service
integration. You are encouraged to take a look at articles in advanced section to spice up your work:

  * [URL Filtering (URL Sandbox)](:apps/url-filtering.html):
    Decide which urls are opened in a default web browser instead of Nuvola Apps.
  * [Configuration and session storage](:apps/configuration-and-session-storage.html):
    Nuvola Runtime allows service integrations to store both a persistent configuration and a temporary session information.
  * [Initialization and Preferences Forms](:apps/initialization-and-preferences-forms.html):
    These forms are useful when you need to get user input.
  * [Web apps with a variable home page URL](:apps/variable-home-page-url.html):
    This article covers Web apps that don't have a single (constant) home page URL, so their home page has to be specified by user.
  * [Custom Actions](:apps/custom-actions.html):
    This article covers API that allows you to add custom actions like thumbs up/down rating.
  * [Translations](:apps/translations.html): How to mark translatable strings for
    [Gettext-based](http://www.gnu.org/software/gettext/manual/gettext.html)
    translations framework for service integration scripts.


[git]: http://git-scm.com/
[me]: http://fenryxo.cz
[JS_STRICT]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions_and_function_scope/Strict_mode
[JS_SEAF]: http://markdalgleish.com/2011/03/self-executing-anonymous-functions/
