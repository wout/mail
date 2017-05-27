[DBus (name = "io.elementary.mail.WebKitExtension")]
public class DOMServer : Object {
    
    private WebKit.WebExtension extension;

    public DOMServer (WebKit.WebExtension extension) {
        this.extension = extension;
    }
    
    public double get_page_height (uint64 page_id) {
        var page = extension.get_page (page_id);
        if (page != null) {
            return page.get_dom_document ().get_document_element ().get_offset_height ();
        }
        return 0;
    }
    
    [DBus (visible = false)]
    public void on_bus_aquired(DBusConnection connection) {
        try {
            connection.register_object("/io/elementary/mail/WebKitExtension", this);
        } catch (IOError error) {
            warning("Could not register service: %s", error.message);
        }
    }
    
    [DBus (visible = false)]
    public void on_page_created (WebKit.WebExtension extension, WebKit.WebPage page) {
        
    }
}

[DBus (name = "org.example.DOMTest")]
public errordomain DOMServerError {
    ERROR
}

[CCode (cname = "G_MODULE_EXPORT webkit_web_extension_initialize", instance_pos = -1)]
void webkit_web_extension_initialize(WebKit.WebExtension extension) {
    DOMServer server = new DOMServer(extension);
    extension.page_created.connect(server.on_page_created);
    Bus.own_name(BusType.SESSION, "io.elementary.mail.WebKitExtension", BusNameOwnerFlags.NONE,
        server.on_bus_aquired, null, () => { warning("Could not aquire name"); });
}

