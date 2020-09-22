/*
 * Copyright 2014-2020 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola {

public class LastfmCompatibleScrobbler: AudioScrobbler {
    public const string HTTP_GET = "GET";
    public const string HTTP_POST = "POST";

    public string? session {get; protected set; default = null;}
    public override bool has_session { get { return session != null; }}
    protected Soup.Session connection;
    protected string api_key;
    protected string api_secret;
    protected string api_root;
    protected string auth_endpoint;
    protected string? token = null;

    public LastfmCompatibleScrobbler(
        Soup.Session connection, string id,
        string name, string auth_endpoint, string api_key, string api_secret, string api_root) {
        GLib.Object(id: id, name: name);
        this.connection = connection;
        this.auth_endpoint = auth_endpoint;
        this.api_key = api_key;
        this.api_secret = api_secret;
        this.api_root = api_root;

        can_update_now_playing = scrobbling_enabled && has_session;
        can_scrobble = scrobbling_enabled && has_session;
        notify.connect_after(on_notify);
    }

    public override Gtk.Widget? get_settings(Drtgtk.Application app) {
        return new LastfmCompatibleScrobblerSettings(this, app);
    }

    /**
     * Generates authorization URL to authorize request token
     *
     * @return authorization URL
     * @throws AudioScrobblerError on failure
     */
    public async string request_authorization() throws AudioScrobblerError {
        // http://www.last.fm/api/show/auth.getToken
        const string API_METHOD = "auth.getToken";
        var params = new HashTable<string, string>(str_hash, str_equal);
        params.insert("method", API_METHOD);
        params.insert("api_key", api_key);

        Json.Object response = yield send_request(HTTP_GET, params);
        if (!response.has_member("token")) {
            throw new AudioScrobblerError.WRONG_RESPONSE(
                "%s %s: Response doesn't contain token member.", id, API_METHOD);
        }

        token = response.get_string_member("token");
        if (token == null || token == "") {
            throw new AudioScrobblerError.WRONG_RESPONSE(
                "%s %s: Response contains empty token member.", id, API_METHOD);
        }

        return "%s?api_key=%s&token=%s".printf(auth_endpoint, api_key, token);
    }

    /**
     * Exchanges authorized request token for session key.
     *
     * @throws AudioScrobblerError on failure
     */
    public async void finish_authorization() throws AudioScrobblerError {
        // http://www.last.fm/api/show/auth.getSession
        const string API_METHOD = "auth.getSession";
        var params = new HashTable<string, string>(str_hash, str_equal);
        params.insert("method", API_METHOD);
        params.insert("api_key", api_key);
        params.insert("token", token);

        Json.Object response = yield send_request(HTTP_GET, params);
        if (!response.has_member("session")) {
            throw new AudioScrobblerError.WRONG_RESPONSE(
                "%s %s: Response doesn't contain session member.", id, API_METHOD);
        }

        Json.Object session_member = response.get_object_member("session");
        if (!session_member.has_member("key")) {
            throw new AudioScrobblerError.WRONG_RESPONSE(
                "%s %s: Response doesn't contain session.key member.", id, API_METHOD);
        }

        string session_key = session_member.get_string_member("key");
        if (session_key == null || session_key == "") {
            throw new AudioScrobblerError.WRONG_RESPONSE(
                "%s %s: Response contain empty session.key member.", id, API_METHOD);
        }

        if (session_member.has_member("name")) {
            username = session_member.get_string_member("name");
        }

        session = session_key;
        token = null;
    }

    public override void drop_session() {
        session = null;
        username = null;
    }

    public override async void retrieve_username() throws AudioScrobblerError {
        const string API_METHOD = "user.getInfo";
        if (session == null) {
            throw new AudioScrobblerError.NO_SESSION("%s %s: There is no authorized session.", id, API_METHOD);
        }

        // http://www.last.fm/api/show/user.getInfo
        var params = new HashTable<string, string>(str_hash, str_equal);
        params.insert("method", API_METHOD);
        params.insert("api_key", api_key);
        params.insert("sk", session);
        Json.Object response = yield send_request(HTTP_GET, params);
        if (!response.has_member("user")) {
            throw new AudioScrobblerError.WRONG_RESPONSE("%s%s: Response doesn't contain user member.", id, API_METHOD);
        }
        Json.Object user = response.get_object_member("user");
        if (!user.has_member("name")) {
            throw new AudioScrobblerError.WRONG_RESPONSE("%s%s: Response doesn't contain name member.", id, API_METHOD);
        }
        username = user.get_string_member("name");
        if (username == null || username == "") {
            throw new AudioScrobblerError.WRONG_RESPONSE("%s%s: Response contains empty username.", id, API_METHOD);
        }
    }

    /**
     * Updates now playing status on Last.fm
     *
     * @param song song name
     * @param artist artist name
     * @throws AudioScrobblerError on failure
     */
    public async override void update_now_playing(string song, string artist) throws AudioScrobblerError {
        return_if_fail(session != null);
        const string API_METHOD = "track.updateNowPlaying";
        debug("%s update now playing: %s by %s", id, song, artist);
        // http://www.last.fm/api/show/track.updateNowPlaying
        var params = new HashTable<string, string>(null, null);
        params.insert("method", API_METHOD);
        params.insert("api_key", api_key);
        params.insert("sk", session);
        params.insert("track", song);
        params.insert("artist", artist);

        Json.Object response = yield send_request(HTTP_POST, params, 20);
        if (!response.has_member("nowplaying")) {
            throw new AudioScrobblerError.WRONG_RESPONSE("%s %s: Response doesn't contain nowplaying member.",
                id, API_METHOD);
        }
    }

    /**
     * Scrobbles track to Last.fm
     *
     * @param song song name
     * @param artist artist name
     * @param timestamp Unix time
     * @throws AudioScrobblerError on failure
     */
    public async override void scrobble_track(string song, string artist, string? album, int64 timestamp)
    throws AudioScrobblerError {
        return_if_fail(session != null);
        debug("%s scrobble: %s by %s from %s, %s", id, song, artist, album, timestamp.to_string());
        // http://www.last.fm/api/show/track.scrobble
        var params = new HashTable<string, string>(null, null);
        params.insert("method", "track.scrobble");
        params.insert("api_key", api_key);
        params.insert("sk", session);
        params.insert("track", song);
        params.insert("artist", artist);
        params.insert("timestamp", timestamp.to_string());
        if (album != null) {
            params.insert("album", album);
        }

        Json.Object response = yield send_request(HTTP_POST, params, 20);
        if (!response.has_member("scrobbles")) {
            throw new AudioScrobblerError.WRONG_RESPONSE("%s: Response doesn't contain scrobbles member.", id);
        }
    }

    /**
     * Send Last.fm API request
     *
     * @param method HTTP method to use to send request
     * @param params Last.fm API parameters of request
     * @return Root JSON object of the response
     * @throws AudioScrobblerError on failure
     */
    private async Json.Object send_request(string method, HashTable<string, string> params, uint retry=0) throws AudioScrobblerError {
        Soup.Message message;
        string request = create_signed_request(params) + "&format=json";
        if (method == HTTP_GET) {
            message = new Soup.Message(method, api_root + "?" + request);
        } else if (method == HTTP_POST) {
            message = new Soup.Message(method, api_root);
            message.set_request("application/x-www-form-urlencoded",
                Soup.MemoryUse.COPY, request.data);
        } else {
            message = null;
            error("%s: Unsupported request method: %s", id, method);
        }

        while (true) {
            try {
                SourceFunc resume = send_request.callback;
                connection.queue_message(message, () => {
                    Idle.add((owned) resume);
                });
                yield;

                string response = (string) message.response_body.flatten().data;
                var parser = new Json.Parser();
                try {
                    parser.load_from_data(response);
                } catch (GLib.Error e) {
                    var data = (string) request.data;
                    if ("Your request timed out" in data) {
                        throw new AudioScrobblerError.RETRY("%s", data);
                    } else {
                        debug("Send request: %s\n---------\n%s\n----------", data, response);
                        throw new AudioScrobblerError.JSON_PARSE_ERROR(e.message);
                    }
                }

                Json.Node root = parser.get_root();
                if (root == null) {
                    throw new AudioScrobblerError.RETRY("%s: Empty response from the server.", id);
                }
                Json.Object root_object = root.get_object();
                if (root_object.has_member("error") && root_object.has_member("message")) {
                    int64 error_code = root_object.get_int_member("error");
                    string? error_message = root_object.get_string_member("message");
                    switch (error_code) {
                    case 9:  // Invalid session key - Please re-authenticate
                        drop_session();
                        throw new AudioScrobblerError.NO_SESSION(
                            "%s: Session expired. Please re-authenticate. %s", id, error_message);
                    case 11:  // Service Offline - This service is temporarily offline. Try again later.
                    case 16:  // There was a temporary error processing your request. Please try again
                    case 29:  // Rate limit exceeded - Your IP has made too many requests in a short period
                        throw new AudioScrobblerError.RETRY("%s: %s", error_code.to_string(), error_message);
                    default:
                        throw new AudioScrobblerError.LASTFM_ERROR(
                            "%s %s: %s", id, error_code.to_string(), error_message);
                    }
                }
                return root_object;
            } catch (AudioScrobblerError e) {
                if (retry == 0 && !(e is AudioScrobblerError.RETRY)) {
                    throw e;
                }

                retry--;
                warning("%s: Retry: %s", id, e.message);
                SourceFunc resume = send_request.callback;
                Timeout.add_seconds(15, (owned) resume);
                yield;
            }
        }
    }

    /**
     * Creates signed request string for Last.fm API call
     *
     * @param params parameters of the request
     */
    private string create_signed_request(HashTable<string, string> params) {
        // See http://www.last.fm/api/desktopauth#6

        // Buffer for request string
        var req_buffer = new StringBuilder();
        // Buffer to compute signature for request
        var sig_buffer = new StringBuilder();

        // Signature requires sorted params
        List<unowned string> keys = params.get_keys();
        keys.sort(strcmp);

        foreach (unowned string key in keys) {
            string val = params[key];
            // signature buffer does not contain "=" and "&"
            // to separate key and value or key-value pairs
            // TODO: how about escaping?
            sig_buffer.append(key);
            sig_buffer.append(val);

            // request buffer contains "=" and "&"
            // to separate key and value or key-value pairs
            append_param(req_buffer, key, val);
        }

        // Append API_SECRET and generate MD5 hash
        sig_buffer.append(api_secret);
        string api_sig = Checksum.compute_for_string(ChecksumType.MD5, sig_buffer.str);
        sig_buffer.truncate();

        // Append signature to the request string
        append_param(req_buffer, "api_sig", api_sig);
        return req_buffer.str;
    }

    /**
     * Appends URL parameter
     *
     * Appends URL parameter in format "key=value" or "&key=value".
     *
     * @param buffer Buffer which parameter will be appended to
     * @param key parameter name
     * @param value parameter value
     */
    private void append_param(StringBuilder buffer, string key, string value) {
        if (buffer.len > 0) {
            buffer.append_c('&');
        }
        buffer.append(Uri.escape_string(key, "", true));
        buffer.append_c('=');
        buffer.append(Uri.escape_string(value, "", true));
    }

    private void on_notify(ParamSpec param) {
        switch (param.name) {
        case "scrobbling-enabled":
        case "session":
            can_scrobble = can_update_now_playing = scrobbling_enabled && has_session;
            break;
        }
    }
}

} // namespace Nuvola
