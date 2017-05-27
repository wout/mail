/* Copyright 2011-2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

// Regex to detect URLs.
// Originally from here: http://daringfireball.net/2010/07/improved_regex_for_matching_urls
public const string URL_REGEX = "(?i)\\b((?:[a-z][\\w-]+:(?:/{1,3}|[a-z0-9%])|www\\d{0,3}[.]|[a-z0-9.\\-]+[.][a-z]{2,4}/)(?:[^\\s()<>]+|\\(([^\\s()<>]+|(\\([^\\s()<>]+\\)))*\\))+(?:\\(([^\\s()<>]+|(\\([^\\s()<>]+\\)))*\\)|[^\\s`!()\\[\\]{};:'\".,<>?«»“”‘’]))";

// Regex to determine if a URL has a known protocol.
public const string PROTOCOL_REGEX = "^(aim|apt|bitcoin|cvs|ed2k|ftp|file|finger|git|gtalk|http|https|irc|ircs|irc6|lastfm|ldap|ldaps|magnet|news|nntp|rsync|sftp|skype|smb|sms|svn|telnet|tftp|ssh|webcal|xmpp):";

// Private use unicode characters are used for quote tokens
public const string QUOTE_START = "";
public const string QUOTE_END = "";

// Validates a URL.  Intended to be used as a RegexEvalCallback.
// Ensures the URL begins with a valid protocol specifier.  (If not, we don't
// want to linkify it.)
public bool is_valid_url(MatchInfo match_info, StringBuilder result) {
    try {
        string? url = match_info.fetch(0);
        Regex r = new Regex(PROTOCOL_REGEX, RegexCompileFlags.CASELESS);
        
        result.append(r.match(url) ? "<a href=\"%s\">%s</a>".printf(url, url) : url);
    } catch (Error e) {
        debug("URL parsing error: %s\n", e.message);
    }
    return false; // False to continue processing.
}

// Converts plain text emails to something safe and usable in HTML.
public string linkify_and_escape_plain_text(string input) throws Error {
    // Convert < and > into non-printable characters, and change & to &amp;.
    string output = input.replace("<", " \01 ").replace(">", " \02 ").replace("&", "&amp;");
    
    // Converts text links into HTML hyperlinks.
    Regex r = new Regex(URL_REGEX, RegexCompileFlags.CASELESS);
    
    output = r.replace_eval(output, -1, 0, 0, is_valid_url);
    return output.replace(" \01 ", "&lt;").replace(" \02 ", "&gt;");
}

public string decorate_quotes(string text) throws Error {
    int level = 0;
    string outtext = "";
    Regex quote_leader = new Regex("^(&gt;)* ?");  // Some &gt; followed by optional space
    
    foreach (string line in text.split("\n")) {
        MatchInfo match_info;
        if (quote_leader.match_all(line, 0, out match_info)) {
            int start, end, new_level;
            match_info.fetch_pos(0, out start, out end);
            new_level = end / 4;  // Cast to int removes 0.25 from space at end, if present
            while (new_level > level) {
                outtext += "<blockquote>";
                level += 1;
            }
            while (new_level < level) {
                outtext += "</blockquote>";
                level -= 1;
            }
            outtext += line.substring(end);
        } else {
            debug("This line didn't match the quote regex: %s", line);
            outtext += line;
        }
    }
    // Close any remaining blockquotes.
    while (level > 0) {
        outtext += "</blockquote>";
        level -= 1;
    }
    return outtext;
}

public string quote_lines(string text) {
    string[] lines = text.split("\n");
    for (int i=0; i<lines.length; i++)
        lines[i] = @"$(Geary.RFC822.Utils.QUOTE_MARKER)" + lines[i];
    return string.joinv("\n", lines);
}

public string resolve_nesting(string text, string[] values) {
    try {
        GLib.Regex tokenregex = new GLib.Regex(@"(.?)$QUOTE_START([0-9]*)$QUOTE_END(?=(.?))");
        return tokenregex.replace_eval(text, -1, 0, 0, (info, res) => {
            int key = int.parse(info.fetch(2));
            string prev_char = info.fetch(1), next_char = info.fetch(3), insert_next = "";
            // Make sure there's a newline before and after the quote.
            if (prev_char != "" && prev_char != "\n")
                prev_char = prev_char + "\n";
            if (next_char != "" && next_char != "\n")
                insert_next = "\n";
            if (key >= 0 && key < values.length) {
                res.append(prev_char + quote_lines(resolve_nesting(values[key], values)) + insert_next);
            } else {
                debug("Regex error in denesting blockquotes: Invalid key");
                res.append("");
            }
            return false;
        });
    } catch (Error error) {
        debug("Regex error in denesting blockquotes: %s", error.message);
        return "";
    }
}

// Returns a URI suitable for an IMG SRC attribute (or elsewhere, potentially) that is the
// memory buffer unpacked into a Base-64 encoded data: URI
public string assemble_data_uri(string mimetype, Geary.Memory.Buffer buffer) {
    // attempt to use UnownedBytesBuffer to avoid memcpying a potentially huge buffer only to
    // free it when the encoding operation is completed
    string base64;
    Geary.Memory.UnownedBytesBuffer? unowned_bytes = buffer as Geary.Memory.UnownedBytesBuffer;
    if (unowned_bytes != null)
        base64 = Base64.encode(unowned_bytes.to_unowned_uint8_array());
    else
        base64 = Base64.encode(buffer.get_uint8_array());
    
    return "data:%s;base64,%s".printf(mimetype, base64);
}

// Turns the data: URI created by assemble_data_uri() back into its components.  The returned
// buffer is decoded.
//
// TODO: Return mimetype
public bool dissasemble_data_uri(string uri, out Geary.Memory.Buffer? buffer) {
    buffer = null;
    
    if (!uri.has_prefix("data:"))
        return false;
    
    // count from semicolon past encoding type specifier
    int start_index = uri.index_of(";");
    if (start_index <= 0)
        return false;
    
    // watch for string termination to avoid overflow
    int base64_len = "base64,".length;
    for (int ctr = 0; ctr < base64_len; ctr++) {
        if (uri[start_index++] == Geary.String.EOS)
            return false;
    }
    
    // avoid a memory copy of the substring by manually calculating the start address
    uint8[] bytes = Base64.decode((string) (((char *) uri) + start_index));
    
    // transfer ownership of the byte array directly to the Buffer; this prevents an
    // unnecessary copy ... save length before transferring ownership (which frees the array)
    int bytes_length = bytes.length;
    buffer = new Geary.Memory.ByteBuffer.take((owned) bytes, bytes_length);
    
    return true;
}

// Escape reserved HTML entities if the string does not have HTML tags.  If there are no tags,
// or if preserve_whitespace_in_html is true, wrap the string a div to preserve whitespace.
public string smart_escape(string? text, bool preserve_whitespace_in_html) {
    if (text == null)
        return text;
    
    string res = text;
    if (!Regex.match_simple("<([A-Z]*)(?: [^>]*)?>.*</(\\1)>|<[A-Z]*(?: [^>]*)?/>", res,
        RegexCompileFlags.CASELESS)) {
        res = Geary.HTML.escape_markup(res);
        preserve_whitespace_in_html = true;
    }
    if (preserve_whitespace_in_html)
        res = @"<div style='white-space: pre;'>$res</div>";
    return res;
}

