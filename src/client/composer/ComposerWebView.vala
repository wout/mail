/*
 * Copyright 2016 Software Freedom Conservancy Inc.
 * Copyright 2016 Michael Gratton <mike@vee.net>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/**
 * A WebView for editing messages in the composer.
 */
public class ComposerWebView : StylishWebView {

    public ComposerWebView () {
        editable = true;
    }

    /**
     * Loads a message HTML body into the view.
     */
    public new void load_html(string body,
                              string signature,
                              string quote,
                              bool top_posting,
                              bool is_draft) {
        warning ("%s, %s, %s", body, signature, quote);
        const string HTML_PRE = """<html><body dir="auto">""";
        const string HTML_POST = """</body></html>""";
        const string BODY_PRE = """
<div id="geary-body">""";
        const string BODY_POST = """</div>
""";
        const string SIGNATURE = """
<div id="geary-signature">%s</div>
""";
        const string QUOTE = """
<div id="geary-quote"><br />%s</div>
""";
        const string CURSOR = "<div><span id=\"cursormarker\"></span><br /></div>";
        const string SPACER = "<div><br /></div>";

        StringBuilder html = new StringBuilder();
        html.append(HTML_PRE);
        if (!is_draft) {
            html.append(BODY_PRE);
            bool have_body = !Geary.String.is_empty(body);
            if (have_body) {
                html.append(body);
            }

            if (!top_posting && !Geary.String.is_empty(quote)) {
                if (have_body) {
                    html.append(SPACER);
                }
                html.append(quote);
            }

            html.append(SPACER);
            html.append(CURSOR);
            html.append(SPACER);
            html.append(BODY_POST);

            if (!Geary.String.is_empty(signature)) {
                html.append_printf(SIGNATURE, signature);
            }

            if (top_posting && !Geary.String.is_empty(quote)) {
                html.append_printf(QUOTE, quote);
            }
        } else {
            html.append(quote);
        }
        html.append(HTML_POST);
        base.load_html((string) html.data);
    }
}

