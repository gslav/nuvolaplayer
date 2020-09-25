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

#if HAVE_CEF
namespace Nuvola {

/* TODO
 * web_app.allow_insecure_content
 * request filtering
 * context menu - password manager
 * JavaScript dialogs
 * network proxy
 */

public class CefEngine : WebEngine {
    private const string ZOOM_LEVEL_CONF = "webview.zoom_level";

    public override Gtk.Widget get_main_web_view() {return web_view;}

    private AppRunnerController runner_app;
    private CefGtk.WebContext web_context;
    private CefGtk.WebView web_view;
    private JsEnvironment? env = null;
    private JSApi api;
    private IpcBus ipc_bus = null;
    private Config config;
    private Drt.KeyValueStorage session;
    private HashTable<string, Variant> worker_data;
    private GenericSet<string> recent_external_uris;
    private static GLib.PatternSpec[] allowed_uri_patterns;

    static construct {
        allowed_uri_patterns = {
            new PatternSpec("https://web.facebook.com/*/oauth*"),
            new PatternSpec("https://www.facebook.com/v*/dialog/oauth*"),
            new PatternSpec("https://www.facebook.com/dialog/oauth*"),
            new PatternSpec("https://www.facebook.com/login*"),
            new PatternSpec("https://accounts.google.com/o/oauth2/*"),
            new PatternSpec("https://accounts.google.com/signin/*"),
            new PatternSpec("https://accounts.google.com/ServiceLogin*"),
            new PatternSpec("https://accounts.google.com/CheckCookie*"),
            new PatternSpec("https://accounts.google.com/AccountChooser*"),
            new PatternSpec("https://accounts.google.com/Logout*"),
            new PatternSpec("https://accounts.youtube.com/accounts/SetSID?*"),
        };
    }
    public CefEngine(CefOptions web_options, WebApp web_app) {
        base(web_options, web_app);
        web_context = web_options.default_context;
    }

    public override void early_init(AppRunnerController runner_app, IpcBus ipc_bus,
        Config config, Connection? connection, HashTable<string, Variant> worker_data) {
        this.ipc_bus = ipc_bus;
        this.runner_app = runner_app;
        this.config = config;
        this.web_worker = new RemoteWebWorker(ipc_bus);
        this.recent_external_uris = new GenericSet<string>(str_hash, str_equal);
        this.worker_data = worker_data;
        worker_data["NUVOLA_API_ROUTER_TOKEN"] = ipc_bus.router.hex_token;
        worker_data["WEBKITGTK_MAJOR"] = 0;
        worker_data["WEBKITGTK_MINOR"] = 0;
        worker_data["WEBKITGTK_MICRO"] = 0;
        worker_data["LIBSOUP_MAJOR"] = Soup.get_major_version();
        worker_data["LIBSOUP_MINOR"] = Soup.get_minor_version();
        worker_data["LIBSOUP_MICRO"] = Soup.get_micro_version();

        runner_app.replace_mainloop(new CefMainLoopAdaptor());

        if (web_app.allow_insecure_content) {
            warning("Not implemented: web_app.allow_insecure_content");
        }

        session = new Drt.KeyValueMap();
        register_ipc_handlers();
        web_view = new CefGtk.WebView(web_context);
        config.set_default_value(ZOOM_LEVEL_CONF, 0.0);
        web_view.zoom_level = config.get_double(ZOOM_LEVEL_CONF);
        web_view.load_started.connect(on_load_started);
        web_view.alert_dialog.connect(on_alert_dialog);
        web_view.navigation_request.connect(on_navigation_request);
        if (web_view.rendering_mode != CefGtk.RenderingMode.OFFSCREEN) {
            web_view.margin_top = 1;
        }

        HashTable<string, Variant> data = worker_data;
        uint size = data.size();
        var args = new Variant?[2 * size];
        HashTableIter<string, Variant> iter = HashTableIter<string, Variant>(data);
        unowned string key = null;
        unowned Variant val = null;
        for (var i = 0; i < size && iter.next(out key, out val); i++) {
            args[2 * i] = new Variant.string(key);
            args[2 * i + 1] = val;
        }
        string path = Nuvola.get_libdir() + "/libnuvolaruntime-cef-worker.so";
        web_view.add_autoloaded_renderer_extension(path, args);
    }

    ~CefEngine() {
    }

    public override void init() {

        web_view.load_html("<html><body>A web app will be loaded shortly...</body><script>window.title = \"\";</script></html>", WEB_ENGINE_LOADING_URI);
    }

    public override void init_app_runner() {
        if (!ready) {
            web_view.notify.connect_after(on_web_view_notify);
            update_from_web_view("is-loading");
            update_from_web_view("can-go-back");
            update_from_web_view("can-go-forward");

            env = new JsRuntime();
            uint[] webkit_version = {0, 0, 0};
            uint[] libsoup_version = {
                Soup.get_major_version(),
                Soup.get_minor_version(),
                Soup.get_micro_version()};
            api = new JSApi(
                runner_app.storage, web_app.data_dir, storage.config_dir, config, session, webkit_version,
                libsoup_version, false);
            api.call_ipc_method_void.connect(on_call_ipc_method_void);
            api.call_ipc_method_sync.connect(on_call_ipc_method_sync);
            api.call_ipc_method_async.connect(on_call_ipc_method_async);

            try {
                api.inject(env, Utils.extract_js_properties(worker_data));
                api.initialize(env);
            } catch (JSError e) {
                runner_app.fatal_error("Initialization error", e.message);
            }
            try {
                var args = new Variant("(s)", "InitAppRunner");
                env.call_function_sync("Nuvola.core.emit", ref args);
            } catch (GLib.Error e) {
                runner_app.fatal_error("Initialization error",
                    "%s failed to initialize app runner. Initialization exited with error:\n\n%s".printf(
                        runner_app.app_name, e.message));
            }
            debug("App Runner Initialized");
            ready = true;
        }
        if (!request_init_form()) {
            debug("App Runner Ready");
            app_runner_ready();
        }
    }

    public override void load_app() {
        try {
            string? url = env.send_data_request_string("LastPageRequest", "url");
            if (url != null) {
                if (load_uri(url)) {
                    return;
                } else {
                    runner_app.show_error("Invalid page URL",
                        "The web app integration script has not provided a valid page URL '%s'.".printf(url));
                }
            }
        } catch (GLib.Error e) {
            runner_app.show_error("Initialization error",
                ("%s failed to retrieve a last visited page from previous session."
                    + " Initialization exited with error:\n\n%s").printf(runner_app.app_name, e.message));
        }
        go_home();
    }

    public override void go_home() {
        try {
            string url = env.send_data_request_string("HomePageRequest", "url");
            if (url == null) {
                runner_app.fatal_error("Invalid home page URL",
                    "The web app integration script has provided an empty home page URL.");
            } else if (!load_uri(url)) {
                runner_app.fatal_error("Invalid home page URL",
                    "The web app integration script has not provided a valid home page URL '%s'.".printf(url));
            }
        } catch (GLib.Error e) {
            runner_app.fatal_error("Initialization error",
                "%s failed to retrieve a home page of  a web app. Initialization exited with error:\n\n%s".printf(
                    runner_app.app_name, e.message));
        }
    }

    public override string? get_url() {
        return web_view != null ? web_view.uri : null;
    }

    public override void load_url(string url) {
        load_uri(url);
    }

    private bool load_uri(string uri) {
        if (uri.has_prefix("http://") || uri.has_prefix("https://") || uri.has_prefix("chrome://")) {
            web_view.load_uri(uri);
            return true;
        }
        if (uri.has_prefix("nuvola://")) {
            web_view.load_uri(web_app.data_dir.get_child(uri.substring(9)).get_uri());
            return true;
        }
        if (uri.has_prefix(web_app.data_dir.get_uri())) {
            web_view.load_uri(uri);
            return true;
        }
        return false;
    }

    public override void go_back() {
        web_view.go_back();
    }

    public override void go_forward() {
        web_view.go_forward();
    }

    public override void reload() {
        web_view.reload();
    }

    public override void zoom_in() {
        web_view.zoom_in();
    }

    public override void zoom_out() {
        web_view.zoom_out();
    }

    public override void zoom_reset() {
        web_view.zoom_reset();
    }

    public override void get_preferences(out Variant values, out Variant entries) {
        var args = new Variant("(s@a{sv}@av)", "PreferencesForm",
            new Variant.array(new VariantType("{sv}"), {}), new Variant.array(VariantType.VARIANT, {}));
        try {
            env.call_function_sync("Nuvola.core.emit", ref args);
        } catch (GLib.Error e) {
            runner_app.show_error("Integration error", "%s failed to load preferences with error:\n\n%s".printf(
                runner_app.app_name, e.message));
        }
        args.get("(s@a{smv}@av)", null, out values, out entries);
    }

    public override void call_function_sync(string name, ref Variant? params, bool propagate_error=false)
    throws GLib.Error {
        env.call_function_sync(name, ref params);
    }

    private bool request_init_form() {
        Variant values;
        Variant entries;
        var args = new Variant(
            "(s@a{sv}@av)", "InitializationForm",
            new Variant.array(new VariantType("{sv}"), {}), new Variant.array(VariantType.VARIANT, {}));
        try {
            env.call_function_sync("Nuvola.core.emit", ref args);
        } catch (GLib.Error e) {
            runner_app.fatal_error(
                "Initialization error",
                "%s failed to crate initialization form. Initialization exited with error:\n\n%s".printf(
                    runner_app.app_name, e.message));
            return false;
        }
        args.get("(s@a{smv}@av)", null, out values, out entries);
        HashTable<string, Variant> values_hashtable = Drt.VariantUtils.to_hash_table(values);
        if (values_hashtable.size() > 0) {
            debug("Init form requested");
            init_form(values_hashtable, entries);
            return true;
        }
        return false;
    }

    private void register_ipc_handlers() {
        assert(ipc_bus != null);
        Drt.RpcRouter router = ipc_bus.router;
        message("Partially implemented: register_ipc_handlers()");
        router.add_method("/nuvola/core/web-worker-initialized", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Notify that the web worker has been initialized.",
            handle_web_worker_initialized, null);
        router.add_method("/nuvola/core/web-worker-ready", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Notify that the web worker is ready.",
            handle_web_worker_ready, null);
        router.add_method("/nuvola/core/get-data-dir", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            "Return data directory.",
            handle_get_data_dir, null);
        router.add_method("/nuvola/core/get-user-config-dir", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            "Return user config directory.",
            handle_get_user_config_dir, null);

        router.add_method("/nuvola/core/session-has-key", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            "Whether the session has a given key.",
            handle_session_has_key, {
                new Drt.StringParam("key", true, false, null, "Session key.")
            });
        router.add_method("/nuvola/core/session-get-value", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            "Get session value for the given key.",
            handle_session_get_value, {
                new Drt.StringParam("key", true, false, null, "Session key.")
            });
        router.add_method("/nuvola/core/session-set-value", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Set session value for the given key.",
            handle_session_set_value, {
                new Drt.StringParam("key", true, false, null, "Session key."),
                new Drt.VariantParam("value", true, true, null, "Session value.")
            });
        router.add_method("/nuvola/core/session-set-default-value", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Set default session value for the given key.",
            handle_session_set_default_value, {
                new Drt.StringParam("key", true, false, null, "Session key."),
                new Drt.VariantParam("value", true, true, null, "Session value.")
            });
        router.add_method("/nuvola/core/config-has-key", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            "Whether the config has a given key.",
            handle_config_has_key, {
                new Drt.StringParam("key", true, false, null, "Config key.")
            });
        router.add_method("/nuvola/core/config-get-value", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.READABLE,
            "Get config value for the given key.",
            handle_config_get_value, {
                new Drt.StringParam("key", true, false, null, "Config key.")
            });
        router.add_method("/nuvola/core/config-set-value", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Set config value for the given key.",
            handle_config_set_value, {
                new Drt.StringParam("key", true, false, null, "Config key."),
                new Drt.VariantParam("value", true, true, null, "Config value.")
            });
        router.add_method("/nuvola/core/config-set-default-value", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Set default config value for the given key.",
            handle_config_set_default_value, {
                new Drt.StringParam("key", true, false, null, "Config key."),
                new Drt.VariantParam("value", true, true, null, "Config value.")
            });

        router.add_method("/nuvola/browser/download-file-async", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Download file.",
            handle_download_file_async, {
                new Drt.StringParam("uri", true, false, null, "File to download."),
                new Drt.StringParam("basename", true, false, null, "Basename of the file."),
                new Drt.DoubleParam("callback-id", true, null, "Callback id.")
            });
        router.add_method("/nuvola/core/show-error", Drt.RpcFlags.PRIVATE|Drt.RpcFlags.WRITABLE,
            "Show error message.",
            handle_show_error, {
                new Drt.StringParam("text", true, false, null, "Error message.")
            });
    }

    private bool web_worker_initialized_cb() {
        if (!web_worker.initialized) {
            web_worker.initialized = true;
            debug("Init finished");
            init_finished();
        }
        debug("Web Worker Ready");
        web_worker_ready();
        return false;
    }

    private void handle_get_data_dir(Drt.RpcRequest request) throws Drt.RpcError {
        request.respond(new Variant.string(web_app.data_dir.get_path()));
    }

    private void handle_get_user_config_dir(Drt.RpcRequest request) throws Drt.RpcError {
        request.respond(new Variant.string(storage.config_dir.get_path()));
    }

    private void handle_web_worker_initialized(Drt.RpcRequest request) throws Drt.RpcError {
        var channel = request.connection as Drt.RpcChannel;
        assert(channel != null);
        ipc_bus.connect_web_worker(channel);
        Idle.add(web_worker_initialized_cb);
        request.respond(null);
    }

    private void handle_web_worker_ready(Drt.RpcRequest request) throws Drt.RpcError {
        if (!web_worker.ready) {
            web_worker.ready = true;
        }
        web_worker_ready();
        request.respond(null);
    }

    private void handle_session_has_key(Drt.RpcRequest request) throws Drt.RpcError {
        request.respond(new Variant.boolean(session.has_key(request.pop_string())));
    }

    private void handle_session_get_value(Drt.RpcRequest request) throws Drt.RpcError {
        Variant? response = session.get_value(request.pop_string());
        if (response == null) {
            response = new Variant("mv", null);
        }
        request.respond(response);
    }

    private void handle_session_set_value(Drt.RpcRequest request) throws Drt.RpcError {
        session.set_value(request.pop_string(), request.pop_variant());
        request.respond(null);
    }

    private void handle_session_set_default_value(Drt.RpcRequest request) throws Drt.RpcError {
        session.set_default_value(request.pop_string(), request.pop_variant());
        request.respond(null);
    }

    private void handle_config_has_key(Drt.RpcRequest request) throws Drt.RpcError {
        request.respond(new Variant.boolean(config.has_key(request.pop_string())));
    }

    private void handle_config_get_value(Drt.RpcRequest request) throws Drt.RpcError {
        Variant? response = config.get_value(request.pop_string());
        if (response == null) {
            response = new Variant("mv", null);
        }
        request.respond(response);
    }

    private void handle_config_set_value(Drt.RpcRequest request) throws Drt.RpcError {
        config.set_value(request.pop_string(), request.pop_variant());
        request.respond(null);
    }

    private void handle_config_set_default_value(Drt.RpcRequest request) throws Drt.RpcError {
        config.set_default_value(request.pop_string(), request.pop_variant());
        request.respond(null);
    }

    private void handle_download_file_async(Drt.RpcRequest request) throws Drt.RpcError {
        string? uri = request.pop_string();
        string? basename = request.pop_string();
        double cb_id = request.pop_double();
        File dir = storage.cache_dir.get_child("api-downloads");
        try {
            dir.make_directory_with_parents();
        } catch (GLib.Error e) {}
        File file = dir.get_child(basename);
        try {
            file.@delete();
        } catch (GLib.Error e) {}
        web_view.download_file.begin(uri, file.get_path(), null, (o, res) => {
            bool result = web_view.download_file.end(res);
            int status_code = result ? 200 : 404;
            try {
                var payload = new Variant(
                    "(dbusss)", cb_id, result, status_code, status_code.to_string(),
                    result ? file.get_path() : "", result ? file.get_uri() : "");
                web_worker.call_function_sync("Nuvola.browser._downloadDone", ref payload);
            } catch (GLib.Error e) {
                warning("Communication failed: %s", e.message);
            }
        });
        request.respond(null);
    }

    private void handle_show_error(Drt.RpcRequest request) throws Drt.RpcError {
        runner_app.show_error("Integration error", request.pop_string());
        request.respond(null);
    }

    private void on_load_started(Cef.TransitionType transition) {
        if (web_worker != null) {
            debug("Load started");
        }
    }

    private void on_web_view_notify(GLib.Object? o, ParamSpec param) {
        update_from_web_view(param.name);
    }

    private void on_call_ipc_method_void(string name, Variant? data) {
        try {
            ipc_bus.local.call.begin(name, data, (o, res) => {
                try {
                    ipc_bus.local.call.end(res);
                } catch (GLib.Error e) {
                    warning("IPC call error: %s", e.message);
                }});
        } catch (GLib.Error e) {
            critical("Failed to send message '%s'. %s", name, e.message);
        }
    }

    private void on_call_ipc_method_async(JSApi js_api, string name, Variant? data, int id) {
        try {
            ipc_bus.local.call.begin(name, data, (o, res) => {
                try {
                    Variant? response = ipc_bus.local.call.end(res);
                    js_api.send_async_response(id, response, null);
                } catch (GLib.Error e) {
                    js_api.send_async_response(id, null, e);
                }});
        } catch (GLib.Error e) {
            critical("Failed to send message '%s'. %s", name, e.message);
        }
    }

    private void on_call_ipc_method_sync(string name, Variant? data, ref Variant? result) {
        try {
            result = ipc_bus.local.call_sync(name, data);
        } catch (GLib.Error e) {
            critical("Failed to send message '%s'. %s", name, e.message);
            result = null;
        }
    }

    private void update_from_web_view(string property) {
        switch (property) {
        case "zoom-level":
            config.set_double(ZOOM_LEVEL_CONF, web_view.zoom_level);
            break;
        case "uri":
            var args = new Variant("(sms)", "UriChanged", web_view.uri);
            try {
                env.call_function_sync("Nuvola.core.emit", ref args);
            } catch (GLib.Error e) {
                runner_app.show_error("Integration script error", "The web app integration caused an error: %s".printf(e.message));
            }
            break;
        case "is-loading":
            is_loading = web_view.is_loading;
            break;
        case "can-go-back":
            can_go_back = web_view.can_go_back;
            break;
        case "can-go-forward":
            can_go_forward = web_view.can_go_forward;
            break;
        case "fullscreen":
            var window = web_view.get_toplevel() as Gtk.Window;
            if (window != null) {
                if (web_view.fullscreen) {
                    window.fullscreen();
                } else {
                    window.unfullscreen();
                }
            }
            break;
        }
    }

    private void on_alert_dialog(ref bool handled, string? url, string? message_text, Cef.JsdialogCallback callback) {
        if (!handled) {
            var dialog = new CefScriptDialogModel(Cef.JsdialogType.ALERT, callback, url, message_text, null, web_view.get_snapshot());
            show_script_dialog(dialog);
            handled = dialog.handled;
        }
    }

    private void on_navigation_request(CefGtk.NavigationRequest request) {
        if (!request.new_window && (request.frame == null || request.frame.is_main() == 0)) {
            return;
        }
        unowned string? uri = request.target_url;
        if (uri == null || (!uri.has_prefix("http://") && !uri.has_prefix("https://"))) {
            debug("ignore uri %s", uri);
            return;
        }

        request.allow();
        bool new_window_override = request.new_window;
        string uri_override = uri;
        bool approved = navigation_request(ref uri_override, ref new_window_override);
        debug("Navigation: new window: %s → %s, uri: '%s' → '%s', approved: %s, frame: %s, type: %s, user gesture: %s",
            request.new_window.to_string(), new_window_override .to_string(), uri, uri_override,
            approved.to_string(), request.target_frame_name,
            request.transition_type.to_string(), request.user_gesture.to_string());
        if (uri_override == null || uri_override == "") {
            uri_override = uri;
        }

        string reversed_uri = uri.reverse();
        uint uri_length = uri.length;
        foreach (unowned GLib.PatternSpec pattern in allowed_uri_patterns) {
            if (pattern.match(uri_length, uri, reversed_uri)) {
                debug("Allowed because it matches one of global allowed URIS: '%s'.", uri);
                return;
            }
        }

        // LINK => link navigation
        // CLIENT_REDIRECT_FLAG => `window.location = ...` Issue: tiliado/nuvolaruntime#425
        Cef.TransitionType type_mask = Cef.TransitionType.LINK | Cef.TransitionType.CLIENT_REDIRECT_FLAG;
        if ((request.transition_type & type_mask) != 0 || request.user_gesture) {
            if (approved) {
                if (request.new_window != new_window_override || uri_override != uri) {
                    if (request.new_window != new_window_override && new_window_override) {
                        warning("Overriding of new window flag false -> true hasn't been implemented yet.");
                    }
                    // Open in current window instead of a new window or load a different URL
                    Idle.add(() => {web_view.load_uri(uri_override); return false;});
                    request.cancel();
                }
            } else {
                open_external_uri(uri);
                request.cancel();
            }
        }
    }

    private void open_external_uri(string uri) {
        if (!(uri in recent_external_uris)) {
            runner_app.show_uri(uri);
            recent_external_uris.add(uri);
            Timeout.add(300, () => {
                recent_external_uris.remove(uri);
                return false;
            });
        } else {
            debug("External URI '%s' ignored because it was opened recently.", uri);
        }
    }

    private bool navigation_request(ref string url, ref bool new_window) {
        var builder = new VariantBuilder(new VariantType("a{smv}"));
        builder.add("{smv}", "url", new Variant.string(url));
        builder.add("{smv}", "approved", new Variant.boolean(true));
        builder.add("{smv}", "newWindow", new Variant.boolean(new_window));
        var args = new Variant("(s@a{smv})", "NavigationRequest", builder.end());
        try {
            env.call_function_sync("Nuvola.core.emit", ref args);
        } catch (GLib.Error e) {
            runner_app.show_error("Integration script error", "The web app integration script has not provided a valid response and caused an error: %s".printf(e.message));
            return true;
        }
        VariantIter iter = args.iterator();
        assert(iter.next("s", null));
        VariantIter? dict = null; // "a{smv}" (new allocation)
        assert(iter.next("a{smv}", out dict));
        unowned string key = null; // "&s" (unowned)
        Variant? value = null; // "mv" (new reference)
        bool approved = false;
        while (dict.next("{&smv}", out key, out value)) {
            if (key == "approved") {
                approved = value != null ? value.get_boolean() : false;
            } else if (key == "newWindow" && value != null) {
                new_window = value.get_boolean();
            } else if (key == "url" && value != null) {
                url = value.get_string();
            }
            value = null; // https://gitlab.gnome.org/GNOME/vala/issues/722
        }
        return approved;
    }
}

} // namespace Nuvola
#endif
