import Foundation

func rulesheetHTMLDocumentScript(modeJSON: String, payloadJSON: String) -> String {
    """
    const mode = \(modeJSON);
    const payload = \(payloadJSON);
    const container = document.getElementById('content');
    if (mode === 'html') {
      container.innerHTML = payload;
    } else if (!window.markdownit) {
      container.textContent = payload;
    } else {
      const md = window.markdownit({ html: true, linkify: true, breaks: false });
      container.innerHTML = md.render(payload);
    }
    container.querySelectorAll('table').forEach((table) => {
      if (table.parentElement && table.parentElement.classList.contains('table-scroll')) return;
      const wrapper = document.createElement('div');
      wrapper.className = 'table-scroll';
      table.parentNode.insertBefore(wrapper, table);
      wrapper.appendChild(table);
    });
    """
}
