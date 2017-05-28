namespace MailWebViewExtension {
    [DBus (name = "io.elementary.mail.WebKitExtension")]
    interface Server : Object {
        public abstract double get_page_height (uint64 page_id);
    }
}
