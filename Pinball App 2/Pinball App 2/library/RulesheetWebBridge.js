        (function() {
          function postChromeTap() {
            const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.__PINBALL_CHROME_TAP_MESSAGE_NAME__;
            if (handler) handler.postMessage(null);
          }

          function postFragmentScroll(hash) {
            const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.__PINBALL_FRAGMENT_SCROLL_MESSAGE_NAME__;
            if (!handler) return false;
            handler.postMessage(hash);
            return true;
          }

          function setAnchorOffset(value) {
            const parsed = Number(value);
            window.__pinballAnchorScrollInset = Number.isFinite(parsed) ? parsed : 0;
          }

          function candidateFragments(raw) {
            const values = [];
            if (!raw) return values;
            values.push(raw);
            try {
              const decoded = decodeURIComponent(raw);
              if (!values.includes(decoded)) values.unshift(decoded);
            } catch (_) {}
            return values;
          }

          function resolveTarget(hash) {
            const trimmed = (hash || '').replace(/^#/, '');
            for (const candidate of candidateFragments(trimmed)) {
              const byId = document.getElementById(candidate);
              if (byId) return byId;
              const byName = document.getElementsByName(candidate);
              if (byName && byName.length > 0) return byName[0];
            }
            return null;
          }

          function scrollToHash(hash, behavior) {
            const target = resolveTarget(hash);
            if (!target) return false;
            const fragmentScrollInset = window.matchMedia('(orientation: landscape)').matches
              ? 18
              : ((window.__pinballAnchorScrollInset || 0) + 14);
            const top = Math.max(
              target.getBoundingClientRect().top + window.scrollY - fragmentScrollInset,
              0
            );
            const scrollBehavior = behavior === 'smooth' ? 'smooth' : 'auto';
            window.scrollTo({ top: top, behavior: scrollBehavior });
            if (hash && window.history && window.history.replaceState) {
              window.history.replaceState(null, '', hash);
            }
            return true;
          }

          function blockAnchor() {
            const selectors = [
              'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
              'p', 'li', 'blockquote', 'pre',
              'td', 'th', 'dt', 'dd',
              '.bodyTitle', '.bodySmall'
            ].join(', ');
            const referenceY = (window.__pinballAnchorScrollInset || 0) + 24;
            const candidates = Array.from(document.querySelectorAll(selectors));
            let target = null;
            let bestDistance = Number.POSITIVE_INFINITY;

            for (const candidate of candidates) {
              const rect = candidate.getBoundingClientRect();
              if (!rect || rect.height < 1) continue;
              const distance = rect.top <= referenceY && rect.bottom >= referenceY
                ? 0
                : Math.min(Math.abs(rect.top - referenceY), Math.abs(rect.bottom - referenceY));
              if (distance < bestDistance) {
                target = candidate;
                bestDistance = distance;
                if (distance === 0) break;
              }
            }

            if (!target) {
              target = document.getElementById('content') || document.body;
            }
            if (!target) return null;

            const rect = target.getBoundingClientRect();
            const height = Math.max(rect.height, 1);
            const path = [];
            let current = target;
            while (current && current !== document.body) {
              const parent = current.parentElement;
              if (!parent) return null;
              path.unshift(Array.prototype.indexOf.call(parent.children, current));
              current = parent;
            }

            return {
              path: path,
              offsetRatio: Math.min(Math.max((referenceY - rect.top) / height, 0), 1)
            };
          }

          function clampReferenceY() {
            return Math.min(
              Math.max((window.__pinballAnchorScrollInset || 0) + 24, 0),
              Math.max(window.innerHeight - 1, 0)
            );
          }

          function candidateReferenceXs() {
            const raw = [
              window.innerWidth * 0.5,
              window.innerWidth * 0.42,
              window.innerWidth * 0.58
            ];
            return raw.map(function(value) {
              return Math.min(Math.max(value, 1), Math.max(window.innerWidth - 1, 1));
            });
          }

          function caretRangeAtPoint(x, y) {
            if (document.caretPositionFromPoint) {
              const position = document.caretPositionFromPoint(x, y);
              if (!position || !position.offsetNode) return null;
              const range = document.createRange();
              range.setStart(position.offsetNode, position.offset || 0);
              range.collapse(true);
              return range;
            }

            if (document.caretRangeFromPoint) {
              const range = document.caretRangeFromPoint(x, y);
              if (!range) return null;
              return range.cloneRange();
            }

            return null;
          }

          function nodePath(node) {
            const path = [];
            let current = node;
            while (current && current !== document.body) {
              const parent = current.parentNode;
              if (!parent || !parent.childNodes) return null;
              path.unshift(Array.prototype.indexOf.call(parent.childNodes, current));
              current = parent;
            }
            return path;
          }

          function resolveNodePath(path) {
            if (!Array.isArray(path)) return null;
            let current = document.body;
            for (const rawIndex of path) {
              const index = Number(rawIndex);
              if (!current || !current.childNodes || !Number.isInteger(index) || index < 0 || index >= current.childNodes.length) {
                return null;
              }
              current = current.childNodes[index];
            }
            return current;
          }

          function normalizedTextSnippet(text) {
            return String(text || '').replace(/\\s+/g, ' ').trim().slice(0, 120);
          }

          function rangeContext(range) {
            if (!range) return { before: '', after: '' };
            try {
              const source = range.startContainer && range.startContainer.nodeType === Node.TEXT_NODE
                ? range.startContainer.textContent || ''
                : range.startContainer && range.startContainer.textContent
                  ? range.startContainer.textContent
                  : '';
              const offset = Math.max(Number(range.startOffset) || 0, 0);
              return {
                before: normalizedTextSnippet(source.slice(Math.max(0, offset - 24), offset)),
                after: normalizedTextSnippet(source.slice(offset, offset + 24))
              };
            } catch (_) {
              return { before: '', after: '' };
            }
          }

          function measurableRangeRect(range) {
            if (!range) return null;
            const directRect = range.getBoundingClientRect();
            if (directRect && (directRect.height > 0 || directRect.width > 0)) return directRect;

            const expanded = range.cloneRange();
            const container = expanded.startContainer;
            const offset = expanded.startOffset;

            if (container && container.nodeType === Node.TEXT_NODE) {
              const textLength = (container.textContent || '').length;
              if (offset < textLength) {
                expanded.setEnd(container, Math.min(offset + 1, textLength));
              } else if (offset > 0) {
                expanded.setStart(container, Math.max(offset - 1, 0));
              }
            } else if (container && container.childNodes && container.childNodes.length > 0) {
              const childIndex = Math.min(offset, container.childNodes.length - 1);
              const child = container.childNodes[childIndex];
              if (child) {
                expanded.selectNode(child);
              }
            }

            const fallbackRect = expanded.getBoundingClientRect();
            if (fallbackRect && (fallbackRect.height > 0 || fallbackRect.width > 0)) return fallbackRect;
            const rects = expanded.getClientRects();
            return rects && rects.length > 0 ? rects[0] : null;
          }

          function textBookmark() {
            const referenceY = clampReferenceY();
            for (const x of candidateReferenceXs()) {
              const range = caretRangeAtPoint(x, referenceY);
              if (!range) continue;

              const path = nodePath(range.startContainer);
              if (!path) continue;

              const block = blockAnchor();
              const context = rangeContext(range);
              const rect = measurableRangeRect(range);
              if (!rect) continue;
              if (Math.abs((rect.top + window.scrollY) - (window.scrollY + referenceY)) > 36) continue;
              if (Math.abs((rect.left + (rect.width / 2)) - x) > Math.max(window.innerWidth * 0.2, 64)) continue;
              const liveToken = (window.__pinballViewportBookmarkToken || 0) + 1;

              window.__pinballViewportBookmarkToken = liveToken;
              window.__pinballViewportBookmarkRange = range.cloneRange();

              return {
                kind: 'text',
                liveToken: liveToken,
                nodePath: path,
                offset: Number(range.startOffset) || 0,
                contextBefore: context.before,
                contextAfter: context.after,
                blockAnchor: block,
                referenceY: referenceY,
                measuredTop: rect.top + window.scrollY
              };
            }

            return null;
          }

          function restoreBlockAnchor(anchor) {
            if (!anchor || !Array.isArray(anchor.path)) return false;

            let target = document.body;
            for (const rawIndex of anchor.path) {
              const index = Number(rawIndex);
              if (!target || !target.children || !Number.isInteger(index) || index < 0 || index >= target.children.length) {
                return false;
              }
              target = target.children[index];
            }
            if (!target) return false;

            const rect = target.getBoundingClientRect();
            const height = Math.max(rect.height, 1);
            const offsetRatio = Math.min(Math.max(Number(anchor.offsetRatio) || 0, 0), 1);
            const referenceY = (window.__pinballAnchorScrollInset || 0) + 24;
            const top = Math.max(rect.top + window.scrollY + (offsetRatio * height) - referenceY, 0);
            window.scrollTo({ top: top, behavior: 'auto' });
            return true;
          }

          function restoreTextBookmark(payload) {
            let range = null;
            if (payload && payload.liveToken && window.__pinballViewportBookmarkToken === payload.liveToken && window.__pinballViewportBookmarkRange) {
              range = window.__pinballViewportBookmarkRange.cloneRange();
            }

            if (!range && payload && Array.isArray(payload.nodePath)) {
              const node = resolveNodePath(payload.nodePath);
              if (node) {
                const maxOffset = node.nodeType === Node.TEXT_NODE
                  ? (node.textContent || '').length
                  : (node.childNodes ? node.childNodes.length : 0);
                const offset = Math.min(Math.max(Number(payload.offset) || 0, 0), Math.max(maxOffset, 0));
                range = document.createRange();
                range.setStart(node, offset);
                range.collapse(true);
              }
            }

            if (!range) {
              return payload && payload.blockAnchor ? restoreBlockAnchor(payload.blockAnchor) : false;
            }

            const rect = measurableRangeRect(range);
            if (!rect) {
              return payload && payload.blockAnchor ? restoreBlockAnchor(payload.blockAnchor) : false;
            }

            const referenceY = (window.__pinballAnchorScrollInset || 0) + 24;
            const top = Math.max(rect.top + window.scrollY - referenceY, 0);
            window.scrollTo({ top: top, behavior: 'auto' });
            window.__pinballViewportBookmarkRange = range.cloneRange();
            return true;
          }

          function captureViewportLayoutSnapshot() {
            const selectors = [
              'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
              'p', 'li', 'blockquote', 'pre',
              'td', 'th', 'dt', 'dd',
              '.bodyTitle', '.bodySmall'
            ].join(', ');
            const referenceY = clampReferenceY();
            const referenceX = Math.min(
              Math.max(window.innerWidth / 2, 1),
              Math.max(window.innerWidth - 1, 1)
            );

            const stack = document.elementsFromPoint(referenceX, referenceY);
            let target = null;
            for (const candidate of stack) {
              if (candidate && candidate.matches && candidate.matches(selectors)) {
                target = candidate;
                break;
              }
              if (candidate && candidate.closest) {
                const ancestor = candidate.closest(selectors);
                if (ancestor) {
                  target = ancestor;
                  break;
                }
              }
            }

            if (!target) {
              const anchor = blockAnchor();
              if (anchor && Array.isArray(anchor.path)) {
                let current = document.body;
                for (const rawIndex of anchor.path) {
                  const index = Number(rawIndex);
                  if (!current || !current.children || index < 0 || index >= current.children.length) {
                    current = null;
                    break;
                  }
                  current = current.children[index];
                }
                if (current) target = current;
              }
            }

            if (!target) {
              target = document.getElementById('content') || document.body;
            }
            if (!target) return null;

            const rect = target.getBoundingClientRect();
            const height = Math.max(rect.height, 1);
            const path = [];
            let current = target;
            while (current && current !== document.body) {
              const parent = current.parentElement;
              if (!parent) break;
              path.unshift(Array.prototype.indexOf.call(parent.children, current));
              current = parent;
            }

            const text = (target.innerText || target.textContent || '')
              .replace(/\\s+/g, ' ')
              .trim()
              .slice(0, 120);

            return {
              tagName: (target.tagName || '').toLowerCase(),
              elementID: target.id || null,
              className: (target.className && String(target.className)) || null,
              textSnippet: text || null,
              domPath: path,
              viewportY: referenceY,
              documentY: window.scrollY + referenceY,
              scrollY: window.scrollY,
              viewWidth: window.innerWidth,
              viewHeight: window.innerHeight,
              contentHeight: Math.max(
                document.documentElement ? document.documentElement.scrollHeight : 0,
                document.body ? document.body.scrollHeight : 0
              ),
              maxScrollY: Math.max(
                Math.max(
                  document.documentElement ? document.documentElement.scrollHeight : 0,
                  document.body ? document.body.scrollHeight : 0
                ) - window.innerHeight,
                0
              ),
              scrollRatio: (function() {
                const contentHeight = Math.max(
                  document.documentElement ? document.documentElement.scrollHeight : 0,
                  document.body ? document.body.scrollHeight : 0
                );
                const maxScrollY = Math.max(contentHeight - window.innerHeight, 0);
                if (maxScrollY <= 0) return 0;
                return Math.min(Math.max(window.scrollY / maxScrollY, 0), 1);
              })(),
              elementTop: rect.top + window.scrollY,
              elementHeight: rect.height,
              offsetRatio: Math.min(Math.max((referenceY - rect.top) / height, 0), 1)
            };
          }

          window.__pinballSetAnchorScrollInset = setAnchorOffset;
          window.__pinballScrollToFragment = function(fragment, behavior) {
            const hash = fragment ? (String(fragment).charAt(0) === '#' ? String(fragment) : '#' + String(fragment)) : '';
            return scrollToHash(hash, behavior);
          };
          window.__pinballCaptureViewportLayoutSnapshot = captureViewportLayoutSnapshot;
          window.__pinballCaptureViewportAnchor = function() {
            const textAnchor = textBookmark();
            if (textAnchor) return JSON.stringify(textAnchor);
            const anchor = blockAnchor();
            return anchor ? JSON.stringify({ kind: 'block', blockAnchor: anchor }) : null;
          };
          window.__pinballRestoreViewportAnchor = function(anchor) {
            if (!anchor) return false;
            let payload = anchor;
            if (typeof payload === 'string') {
              try {
                payload = JSON.parse(payload);
              } catch (_) {
                return false;
              }
            }
            if (!payload) return false;
            if (payload.kind === 'text') return restoreTextBookmark(payload);
            if (payload.blockAnchor) return restoreBlockAnchor(payload.blockAnchor);
            return restoreBlockAnchor(payload);
          };
          setAnchorOffset(__PINBALL_INITIAL_ANCHOR_SCROLL_INSET__);

          document.addEventListener('click', function(event) {
            if (event.defaultPrevented) return;
            const target = event.target;
            const anchor = target && target.closest ? target.closest('a[href]') : null;
            if (!anchor) {
              postChromeTap();
              return;
            }

            let destination;
            let current;
            try {
              destination = new URL(anchor.href, window.location.href);
              current = new URL(window.location.href);
            } catch (_) {
              return;
            }

            const sameDocument = !!destination.hash &&
              destination.origin === current.origin &&
              destination.pathname === current.pathname &&
              destination.search === current.search;

            if (!sameDocument) return;

            event.preventDefault();
            if (postFragmentScroll(destination.hash)) return;
            scrollToHash(destination.hash, 'smooth');
          }, true);
        })();
