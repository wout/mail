public class Mail.Backend.Account : GLib.Object {
    public Camel.Service service { get; construct; }
    public Account (Camel.Service service) {
        Object (service: service);
    }
}

