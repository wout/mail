/* Copyright 2011-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public int compare_conversation_ascending(Geary.App.Conversation a, Geary.App.Conversation b) {
    Geary.Email? a_latest = a.get_latest_recv_email(Geary.App.Conversation.Location.IN_FOLDER_OUT_OF_FOLDER);
    Geary.Email? b_latest = b.get_latest_recv_email(Geary.App.Conversation.Location.IN_FOLDER_OUT_OF_FOLDER);
    
    if (a_latest == null)
        return (b_latest == null) ? 0 : -1;
    else if (b_latest == null)
        return 1;
    
    // use date-received so newly-arrived messages float to the top, even if they're send date
    // was earlier (think of mailing lists that batch up forwarded mail)
    return Geary.Email.compare_recv_date_ascending(a_latest, b_latest);
}

public int compare_conversation_descending(Geary.App.Conversation a, Geary.App.Conversation b) {
    return compare_conversation_ascending(b, a);
}

namespace EmailUtil {

public string strip_subject_prefixes(Geary.Email email) {
    string? cleaned = (email.subject != null) ? email.subject.strip_prefixes() : null;
    
    return !Geary.String.is_empty(cleaned) ? cleaned : _("(no subject)");
}

    public bool is_noreply (string address) {
        /// TRANSLATORS: please copy the original string and append all local parts of "no reply" email addresses
        /// (that is the part before the '@') that exist in your language (separated with a semicolon)
        foreach (var member in _("no-reply;no_reply;noreply;do-not-reply;do_not_reply;donotreply").split (";")) {
            if (address.down ().contains (member)) {
                return true;
            }
        }

        return false;
    }

    public string get_mime_content (Camel.MimeMessage message) {
        string current_content = "";
        int content_priority = 0;
        var content = message.content as Camel.Multipart;
        if (content != null) {
            for (uint i = 0; i < content.get_number (); i++) {
                var part = content.get_part (i);
                int current_content_priority = get_content_type_priority (part.get_mime_type ());
                if (current_content_priority > content_priority) {
                    var byte_array = new GLib.ByteArray ();
                    var stream = new Camel.StreamMem.with_byte_array (byte_array);
                    part.decode_to_stream_sync (stream);
                    current_content = (string)byte_array.data;
                }
            }
        }

        return current_content;
    }

    public int get_content_type_priority (string mime_type) {
        switch (mime_type) {
            case "text/plain":
                return 1;
            case "text/html":
                return 2;
            default:
                return 0;
        }
    }
}

