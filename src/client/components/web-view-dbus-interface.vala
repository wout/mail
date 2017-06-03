namespace MailWebViewExtension {
    [DBus (name = "io.elementary.mail.WebKitExtension")]
    interface Server : Object {
        public signal void page_load_changed (uint64 page_id);
        public signal void image_loading_enabled (uint64 page_id);
        public abstract void fire_image_load_blocked (uint64 page_id);
        public abstract void set_height (uint64 view, int height);
        public abstract bool get_load_images (uint64 view);
    }
}
