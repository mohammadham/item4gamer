/**
 * Media Display Fixer
 * رفع مشکلات نمایش media در Shadow DOM
 */

(function() {
  'use strict';

  console.log('Media Display Fixer initialized');

  // CSS برای رفع مشکلات نمایش
  const fixerCSS = `
    /* رفع مشکل audio elements */
    audio {
      display: block !important;
      width: 100% !important;
      max-width: 100% !important;
      visibility: visible !important;
      opacity: 1 !important;
      pointer-events: auto !important;
    }

    /* رفع مشکل image elements */
    img {
      display: inline-block !important;
      max-width: 100% !important;
      height: auto !important;
      visibility: visible !important;
      opacity: 1 !important;
    }

    /* رفع مشکل video elements */
    video {
      display: block !important;
      width: 100% !important;
      max-width: 100% !important;
      visibility: visible !important;
      opacity: 1 !important;
    }

    /* رفع مشکل دکمه‌های پخش */
    button[class*="play"],
    [class*="audio-play"],
    [class*="voice-play"],
    [aria-label*="play" i] {
      display: inline-block !important;
      visibility: visible !important;
      opacity: 1 !important;
      pointer-events: auto !important;
      cursor: pointer !important;
    }

    /* رفع مشکلات container */
    [class*="audio-container"],
    [class*="voice-container"],
    [class*="media-container"],
    [class*="message-media"] {
      display: block !important;
      visibility: visible !important;
      opacity: 1 !important;
    }

    /* رفع مشکل blob images */
    img[src^="blob:"] {
      display: inline-block !important;
      visibility: visible !important;
      opacity: 1 !important;
    }
  `;

  // تزریق CSS به document
  function injectCSSToDocument() {
    const style = document.createElement('style');
    style.id = 'media-display-fixer-style';
    style.textContent = fixerCSS;

    if (document.head) {
      // حذف style قبلی اگر وجود دارد
      const existingStyle = document.getElementById('media-display-fixer-style');
      if (existingStyle) {
        existingStyle.remove();
      }

      document.head.appendChild(style);
      console.log('CSS injected to document head');
    }
  }

  // تزریق CSS به Shadow Roots
  function injectCSSToShadowRoots() {
    const allElements = document.querySelectorAll('*');

    allElements.forEach(element => {
      if (element.shadowRoot) {
        // بررسی اگر قبلاً تزریق شده
        const existingStyle = element.shadowRoot.getElementById('media-display-fixer-shadow-style');
        if (existingStyle) return;

        const style = document.createElement('style');
        style.id = 'media-display-fixer-shadow-style';
        style.textContent = fixerCSS;

        element.shadowRoot.appendChild(style);
        console.log('CSS injected to shadow root');
      }
    });
  }

  // رفع مشکلات inline style
  function fixInlineStyles() {
    // رفع مشکل audio elements
    document.querySelectorAll('audio').forEach(audio => {
      audio.style.display = 'block';
      audio.style.width = '100%';
      audio.controls = true;
    });

    // رفع مشکل در shadow roots
    const allElements = document.querySelectorAll('*');
    allElements.forEach(element => {
      if (element.shadowRoot) {
        element.shadowRoot.querySelectorAll('audio').forEach(audio => {
          audio.style.display = 'block';
          audio.style.width = '100%';
          audio.controls = true;
        });

        element.shadowRoot.querySelectorAll('img').forEach(img => {
          img.style.display = 'inline-block';
          img.style.maxWidth = '100%';
        });
      }
    });
  }

  // مدیریت media elements جدید
  function setupMediaObserver() {
    const observer = new MutationObserver((mutations) => {
      let hasNewMedia = false;

      for (const mutation of mutations) {
        if (mutation.type === 'childList') {
          mutation.addedNodes.forEach(node => {
            if (node.nodeType === Node.ELEMENT_NODE) {
              const element = node;

              // بررسی اگر خود element یک media است
              if (['AUDIO', 'IMG', 'VIDEO'].includes(element.tagName)) {
                hasNewMedia = true;
              }

              // بررسی media داخل element
              if (element.querySelectorAll) {
                const mediaElements = element.querySelectorAll('audio, img, video');
                if (mediaElements.length > 0) {
                  hasNewMedia = true;
                }
              }

              // بررسی shadow root جدید
              if (element.shadowRoot) {
                injectCSSToShadowRoots();
                hasNewMedia = true;
              }
            }
          });
        }
      }

      if (hasNewMedia) {
        fixInlineStyles();
      }
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });

    console.log('Media observer installed');
  }

  // اجرای دوره‌ای
  function periodicFix() {
    injectCSSToDocument();
    injectCSSToShadowRoots();
    fixInlineStyles();
  }

  // Initialize
  function init() {
    console.log('Initializing Media Display Fixer...');

    // اجرای اولیه
    periodicFix();

    // نصب observer
    setupMediaObserver();

    // اجرای دوره‌ای (هر 3 ثانیه)
    setInterval(periodicFix, 3000);

    console.log('Media Display Fixer ready!');
  }

  // شروع
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  // اجرای مجدد برای SPAs
  let lastUrl = location.href;
  new MutationObserver(() => {
    const url = location.href;
    if (url !== lastUrl) {
      lastUrl = url;
      console.log('URL changed, re-applying fixes...');
      setTimeout(periodicFix, 500);
    }
  }).observe(document, { subtree: true, childList: true });

})();
