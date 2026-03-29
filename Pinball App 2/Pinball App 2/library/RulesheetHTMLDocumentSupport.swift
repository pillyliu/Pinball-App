import Foundation

func rulesheetHTMLDocument(modeJSON: String, payloadJSON: String) -> String {
    """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
      <style>
        \(rulesheetHTMLDocumentStyles)
      </style>
      <script src="https://cdn.jsdelivr.net/npm/markdown-it@14.1.0/dist/markdown-it.min.js"></script>
    </head>
    <body>
      <article id="content"></article>
      <script>
        \(rulesheetHTMLDocumentScript(modeJSON: modeJSON, payloadJSON: payloadJSON))
      </script>
    </body>
    </html>
    """
}
