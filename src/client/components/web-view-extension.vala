public class DOMServer : Object {
    private const string[] ALLOWED_SCHEMES = { "cid", "geary", "data" };
    private WebKit.WebExtension extension;

    private MailWebViewExtension.Server ui_process;

    public DOMServer (WebKit.WebExtension extension) {
        this.extension = extension;

        ui_process = Bus.get_proxy_sync (BusType.SESSION, "io.elementary.mail.WebKitExtension", "/io/elementary/mail/WebKitExtension");
        ui_process.page_load_changed.connect (on_page_load_changed);
        ui_process.image_loading_enabled.connect (on_image_loading_enabled);
    }

    private void on_page_load_changed (uint64 page_id) {
        var page = extension.get_page (page_id);
        if (page != null) {
            ui_process.set_height (page_id, (int)page.get_dom_document ().get_document_element ().get_offset_height ());
        }
    }

    private void on_image_loading_enabled (uint64 page_id) {
        if (ui_process.get_load_images (page_id)) {
            var page = extension.get_page (page_id);
            if (page != null) {
                var images = page.get_dom_document ().get_images ();
                for (int i = 0; i < images.length; i++) {
                    var image = (WebKit.DOM.HTMLImageElement)images.item (i);
                    image.set_src (image.get_src ());
                }
            }
        }
    }

    public void on_page_created (WebKit.WebExtension extension, WebKit.WebPage page) {
        page.send_request.connect (on_send_request);
    }

    private bool on_send_request (WebKit.WebPage page,
                                  WebKit.URIRequest request,
                                  WebKit.URIResponse? response) {
        bool should_load = false;
        Soup.URI? uri = new Soup.URI (request.get_uri ());
        if (uri != null && uri.get_scheme () in ALLOWED_SCHEMES) {
            // Always load internal resources
            should_load = true;
        } else {
            if (ui_process.get_load_images (page.get_id ())) {
                should_load = true;
            } else {
                ui_process.fire_image_load_blocked (page.get_id ());
            }
        }

        return should_load ? Gdk.EVENT_PROPAGATE : Gdk.EVENT_STOP;
    }
}

[CCode (cname = "G_MODULE_EXPORT webkit_web_extension_initialize", instance_pos = -1)]
public void webkit_web_extension_initialize(WebKit.WebExtension extension) {
    DOMServer server = new DOMServer (extension);
    extension.page_created.connect (server.on_page_created);
    server.ref ();
}

