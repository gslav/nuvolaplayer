/*
 * Copyright 2017-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

namespace Nuvola.Graphics {

#if FLATPAK
public string? get_required_gl_extension() {
    unowned string? flatpak_gl_drivers_list = Environment.get_variable("FLATPAK_GL_DRIVERS");
    if (flatpak_gl_drivers_list != null) {
        debug("FLATPAK_GL_DRIVERS: '%s'", flatpak_gl_drivers_list);
        string[] flatpak_gl_drivers = flatpak_gl_drivers_list.split(":");
        foreach (unowned string driver in flatpak_gl_drivers) {
            string norm_driver = driver.strip();
            if (norm_driver.has_prefix("nvidia-")) {
                return norm_driver;
            }
        }
        return null;
    }
    try {
        string nvidia_version = Drt.System.read_file(File.new_for_path("/sys/module/nvidia/version")).strip();
        if (nvidia_version != "") {
            bool i915 = FileUtils.test("/sys/module/i915", FileTest.EXISTS);
            bool bumblebeed = FileUtils.test("/sys/fs/cgroup/pids/system.slice/bumblebeed.service", FileTest.EXISTS);
            bool ignored = i915 && bumblebeed;  // tiliado/nuvolaruntime#380
            debug("Nvidia %s, i915 %d, bumblebeed %d => ignored %d",
                nvidia_version, (int) i915, (int) bumblebeed, (int) ignored);
            return ignored ? null : "nvidia-" + nvidia_version.replace(".", "-");
        }
    } catch (GLib.Error e) {
        if (!(e is GLib.IOError.NOT_FOUND)) {
            error("Unexpected error: %s", e.message);
        }
    }
    return null;
}

public bool is_required_gl_extension_mounted(out string? gl_extension) {
    gl_extension = get_required_gl_extension();
    if (gl_extension == null) {
        return true;
    } else {
        (unowned string)[] GL_PATHS = {"/usr/lib/x86_64-linux-gnu/GL", "/usr/lib/GL"};
        foreach (unowned string gl_path in GL_PATHS) {
            if (File.new_for_path(gl_path).get_child(gl_extension).query_exists()) {
                return true;
            }
        }
        return false;
    }
}

public void ensure_gl_extension_mounted(Gtk.Window? parent_window) {
    string? gl_extension = null;
    if (!is_required_gl_extension_mounted(out gl_extension)) {
        var dialog = new Gtk.MessageDialog.with_markup(
            parent_window, Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.CLOSE,
            ("<b><big>Missing Graphics Driver</big></b>\n\n"
                + "Graphics driver '%s' for Flatpak has not been found on your system. "
                + "Please consult <a href=\"https://github.com/tiliado/nuvolaplayer/wiki/Graphics-Drivers\">documentation "
                + "on graphics drivers</a> to get help with installation."), gl_extension);
        Timeout.add_seconds(120, () => { dialog.destroy(); return false;});
        dialog.run();
        error("GL extension not found: %s", gl_extension);
    }
}
#endif

const Dri2.EventOps DRI2_NO_OPS = {};

public errordomain DriError {
    NO_X_DISPLAY,
    INIT_DISPLAY,
    EXTENSION_QUERY,
    VERSION_QUERY,
    CONNECT;
}

/**
 * Get the name of DRI2 driver
 *
 * @return driver name
 * @throws DriError on failure
 */
public string dri2_get_driver_name() throws DriError {
    var dpy = new X.Display(null);
    if (dpy == null) {
        throw new DriError.NO_X_DISPLAY("Cannot connect to X display.");
    }
    int major, minor;
    string driver;
    dri2_connect(dpy, out major, out minor, out driver);
    debug("DRI %d.%d; driver %s", major, minor, driver);
    return driver;
}

private void dri2_connect(X.Display dpy, out int major, out int minor, out string driver) throws DriError {
    major = 0;
    minor = 0;
    int driverType = Dri2.DriverDRI;
    driver = null;
    int eventBase, errorBase;
    string? device = null;

    if (!Dri2.init_display(dpy, DRI2_NO_OPS)) {
        throw new DriError.INIT_DISPLAY("DRI2InitDisplay failed.");
    }

    if (!Dri2.query_extension(dpy, out eventBase, out errorBase)) {
        throw new DriError.EXTENSION_QUERY("DRI2QueryExtension failed, %d, %d", eventBase, errorBase);
    }

    if (!Dri2.query_version(dpy, out major, out minor)) {
        throw new DriError.VERSION_QUERY("DRI2QueryVersion failed");
    }

    if (!Dri2.connect(dpy, dpy.default_root_window(), driverType, out driver, out device)) {
        throw new DriError.CONNECT("DRI2Connect failed");
    }
}

/**
 * Check whether VDPAU driver is available
 *
 * @param name    The driver name.
 * @return `true` if the corresponding `libvdpau_XXX.so` has been found, false otherwise.
 */
public bool have_vdpau_driver(string name) {
    string filename = "/usr/lib/vdpau/libvdpau_%s.so".printf(name);
    var paths = new StringBuilder(filename);
    if (FileUtils.test(filename, FileTest.EXISTS)) {
        debug("VDPAU driver found: %s", filename);
        return true;
    }
    SList<string> libdirs = Drt.String.split_strip(Environment.get_variable("LD_LIBRARY_PATH"), ":");
    #if FLATPAK
    // The latest flatpak does not set LD_LIBRARY_PATH anymore.
    // flatpak/flatpak#1073 tiliado/nuvolaruntime#280
    libdirs.append("/app/lib");
    #endif
    foreach (unowned string libdir in libdirs) {
        filename = "%s/vdpau/libvdpau_%s.so".printf(libdir, name);
        paths.append_c(':').append(filename);
        if (FileUtils.test(filename, FileTest.EXISTS)) {
            debug("VDPAU driver found: %s", filename);
            return true;
        }
    }
    debug("%s: VDPAU driver paths: %s", name, paths.str);
    return false;
}

/**
 * Check whether VA-API driver is available
 *
 * @param name    The driver name.
 * @return `true` if the corresponding `dri/XXX_dri_video.so` has been found, false otherwise.
 */
public bool have_vaapi_driver(string name) {
    string filename = "/usr/lib/dri/%s_drv_video.so".printf(name);
    var paths = new StringBuilder(filename);
    if (FileUtils.test(filename, FileTest.EXISTS)) {
        debug("VA-API driver found: %s", filename);
        return true;
    }
    SList<string> libdirs = Drt.String.split_strip(Environment.get_variable("LIBVA_DRIVERS_PATH"), ":");
    foreach (unowned string libdir in libdirs) {
        filename = "%s/%s_drv_video.so".printf(libdir, name);
        paths.append_c(':').append(filename);
        if (FileUtils.test(filename, FileTest.EXISTS)) {
            debug("VA-API driver found: %s", filename);
            return true;
        }
    }
    debug("%s: VA-API driver paths: %s", name, paths.str);
    return false;
}

} // namespace Nuvola.Graphics
