/* Copyright 2014-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class StylishWebView : WebKit.WebView {

    /** URI Scheme and delimiter for internal resource loads. */
    public const string INTERNAL_URL_PREFIX = "geary:";

    /** URI for internal message body page loads. */
    public const string INTERNAL_URL_BODY = INTERNAL_URL_PREFIX + "body";
    
    private string _document_font;
    public string document_font {
        get {
            return _document_font;
        }
        set {
            _document_font = value;
            Pango.FontDescription font = Pango.FontDescription.from_string(value);
            WebKit.Settings config = get_settings ();
            config.default_font_family = font.get_family();
            config.default_font_size = font.get_size() / Pango.SCALE;
            set_settings (config);
            document_font_changed();
        }
    }
    
    private string _monospace_font;
    public string monospace_font {
        get {
            return _monospace_font;
        }
        set {
            _monospace_font = value;
            Pango.FontDescription font = Pango.FontDescription.from_string(value);
            WebKit.Settings config = get_settings ();
            config.monospace_font_family = font.get_family();
            config.default_monospace_font_size = font.get_size() / Pango.SCALE;
            set_settings (config);
            monospace_font_changed();
        }
    }
    
    private string _interface_font;
    public string interface_font {
        get {
            return _interface_font;
        }
        set {
            _interface_font = value;
            interface_font_changed();
        }
    }
    
    public signal void document_font_changed();
    public signal void monospace_font_changed();
    public signal void interface_font_changed();
    public signal void link_activated (string uri);

    private int preferred_height = 0;
    private MailWebViewExtension.Server extension;
    
    public StylishWebView() {
        Settings system_settings = GearyApplication.instance.config.gnome_interface;
        system_settings.bind("document-font-name", this, "document-font", SettingsBindFlags.DEFAULT);
        system_settings.bind("monospace-font-name", this, "monospace-font", SettingsBindFlags.DEFAULT);
        system_settings.bind("font-name", this, "interface-font", SettingsBindFlags.DEFAULT);

        decide_policy.connect (on_decide_policy);

        extension = Bus.get_proxy_sync (BusType.SESSION, "io.elementary.mail.WebKitExtension",
                                                    "/io/elementary/mail/WebKitExtension");
        load_changed.connect (on_load_changed);
    }

    public void on_load_changed (WebKit.LoadEvent event) {
        if (event == WebKit.LoadEvent.FINISHED || event == WebKit.LoadEvent.COMMITTED) {
            preferred_height = (int) extension.get_page_height (get_page_id ());
            queue_resize ();
        }
    }
    
    public override void get_preferred_width (out int minimum_width, out int natural_width) {
        base.get_preferred_width (out minimum_width, out natural_width);
        minimum_width = 100;
        natural_width = int.max (natural_width, minimum_width);
    }

    public override void get_preferred_height (out int minimum_height, out int natural_height) {
        base.get_preferred_height (out minimum_height, out natural_height);
        minimum_height = natural_height = preferred_height;
    }

    /**
     * Loads a message HTML body into the view.
     */
    public new void load_html(string? body, string? base_uri=null) {
        base.load_html(body, base_uri ?? INTERNAL_URL_BODY);
    }

    private bool on_decide_policy(WebKit.WebView view,
                                  WebKit.PolicyDecision policy,
                                  WebKit.PolicyDecisionType type) {
        if (type == WebKit.PolicyDecisionType.NAVIGATION_ACTION ||
            type == WebKit.PolicyDecisionType.NEW_WINDOW_ACTION) {
            WebKit.NavigationPolicyDecision nav_policy =
                (WebKit.NavigationPolicyDecision) policy;
            switch (nav_policy.get_navigation_type()) {
            case WebKit.NavigationType.OTHER:
                if (nav_policy.request.uri == INTERNAL_URL_BODY) {
                    policy.use();
                } else {
                    policy.ignore();
                }
                break;

            case WebKit.NavigationType.LINK_CLICKED:
                // Let the app know a user activated a link, but don't
                // try to load it ourselves.
                link_activated(nav_policy.request.uri);
                policy.ignore();
                break;

            default:
                policy.ignore();
                break;
            }
        } else {
            policy.ignore();
        }
        return Gdk.EVENT_STOP;
    }
}

