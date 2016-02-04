/* Copyright 2011-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * Interface for creating a Nautilus-style "pill" toolbar.  Use only as directed.
 *
 * Subclasses should inherit from some Gtk.Container and provide pack_start() and
 * pack_end() methods with the correct signature.  They also need to have action_group
 * and size properties and call initialize() in their constructors.
 */
public interface PillBar : Gtk.Container {
    protected abstract Gtk.ActionGroup action_group { get; set; }

    protected virtual void initialize(Gtk.ActionGroup toolbar_action_group) {
        action_group = toolbar_action_group;
    }

    public virtual void setup_button (Gtk.Button b, string? icon_name, string action_name, bool show_label = false) {
        b.related_action = action_group.get_action(action_name);
        b.tooltip_text = b.related_action.tooltip;
        b.related_action.notify["tooltip"].connect(() => { b.tooltip_text = b.related_action.tooltip; });

        // Load icon by name with this fallback order: specified icon name, the action's icon name,
        // the action's stock ID ... although stock IDs are being deprecated, that's how we specify
        // the icon in the GtkActionEntry (also being deprecated) and GTK+ 3.14 doesn't support that
        // any longer
        string? icon_to_load = icon_name ?? b.related_action.icon_name;
        if (icon_to_load == null)
            icon_to_load = b.related_action.stock_id;

        if (icon_to_load != null) {
            Gtk.Image image = new Gtk.Image.from_icon_name(icon_to_load, Gtk.IconSize.MENU);
            b.image = image;
        }

        b.always_show_image = true;

        if (!show_label)
            b.label = null;
    }

    /**
     * Given an icon and action, creates a button that triggers the action.
     */
    public virtual Gtk.Button create_toolbar_button(string? icon_name, string action_name, bool show_label = false) {
        Gtk.Button b = new Gtk.Button();
        setup_button(b, icon_name, action_name, show_label);

        return b;
    }

    /**
     * Given a list of buttons, creates a "pill-style" tool item that can be appended to this
     * toolbar.  Optionally adds spacers "before" and "after" the buttons (those terms depending
     * on Gtk.TextDirection)
     */
    public virtual Gtk.Box create_pill_buttons (Gee.Collection<Gtk.Button> buttons, bool before_spacer = true, bool after_spacer = false) {
        Gtk.Box box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        box.valign = Gtk.Align.CENTER;
        box.halign = Gtk.Align.CENTER;

        if (buttons.size > 1) {
            box.get_style_context().add_class(Gtk.STYLE_CLASS_LINKED);
        }

        foreach(Gtk.Button button in buttons) {
            box.add(button);
        }

        return box;
    }
}

/**
 * A pill-style header bar.
 */
public class PillHeaderbar : Gtk.HeaderBar, PillBar {
    protected Gtk.ActionGroup action_group { get; set; }

    public PillHeaderbar(Gtk.ActionGroup toolbar_action_group) {
        initialize(toolbar_action_group);
    }

    public bool close_button_at_end() {
        string layout;
        bool at_end = false;
        layout = Gtk.Settings.get_default().gtk_decoration_layout;
        // Based on logic of close_button_at_end in gtkheaderbar.c: Close button appears
        // at end iff "close" follows a colon in the layout string.
        if (layout != null) {
            int colon_ind = layout.index_of(":");
            at_end = (colon_ind >= 0 && layout.index_of("close", colon_ind) >= 0);
        }
        return at_end;
    }
}

/**
 * A pill-style toolbar.
 */
public class PillToolbar : Gtk.Box, PillBar {
    protected Gtk.ActionGroup action_group { get; set; }

    public PillToolbar(Gtk.ActionGroup toolbar_action_group) {
        Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 6);
        initialize(toolbar_action_group);
    }
}

