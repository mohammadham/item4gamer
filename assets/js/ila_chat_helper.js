/**
 * ILA Chat Helper
 * راه‌حل اختصاصی برای مشکلات Shadow DOM در ila chat
 */

(function() {
  'use strict';

  console.log('ILA Chat Helper initialized');

  // شناسایی ila chat در صفحه
  function detectIlaChat() {
    // جستجوی المان‌های مرتبط با ila chat
    const ilaChatSelectors = [
      '[class*="ila"]',
      '[id*="ila"]',
      '[class*="chat"]',
      '[id*="chat"]',
      'ila-chat',
      'ilachat',
      '[data-ila]'
    ];

    for (const selector of ilaChatSelectors) {
      const elements = document.querySelectorAll(selector);
      if (elements.length > 0) {
        console.log('ILA Chat elements found:', selector, elements.length);
        return true;
      }
    }

    return false;
  }

  // مدیریت دکمه‌های پخش صدا
  function handleAudioButtons() {
    // جستجوی همه دکمه‌های play
    const playButtons = document.querySelectorAll('[class*="play"], [class*="audio"], button[aria-label*="play" i]');

    playButtons.forEach(button => {
      if (button._ilaAudioHandlerAdded) return;
      button._ilaAudioHandlerAdded = true;

      button.addEventListener('click', function(e) {
        console.log('Audio play button clicked');

        // جستجوی عنصر audio مرتبط
        const audioElement = button.closest('[class*="message"]')?.querySelector('audio') ||
                           button.parentElement?.querySelector('audio') ||
                           button.querySelector('audio');

        if (audioElement) {
          console.log('Associated audio element found:', audioElement.src);

          // ارسال به Flutter
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('ilaAudioPlayClicked', {
              audioSrc: audioElement.src,
              buttonElement: button.className,
              timestamp: Date.now()
            }).catch(err => console.error('Error sending audio play event:', err));
          }
        }
      }, { capture: true });
    });
  }

  // مدیریت تصاویر قابل کلیک
  function handleImages() {
    const images = document.querySelectorAll('img[src]');

    images.forEach(img => {
      if (img._ilaImageHandlerAdded) return;
      img._ilaImageHandlerAdded = true;

      // فورس کردن display
      img.style.display = 'inline-block';
      img.style.maxWidth = '100%';

      img.addEventListener('click', function(e) {
        console.log('Image clicked:', img.src);

        // ارسال به Flutter
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('ilaImageClicked', {
            imageSrc: img.src,
            alt: img.alt,
            width: img.width,
            height: img.height,
            timestamp: Date.now()
          }).catch(err => console.error('Error sending image click event:', err));
        }
      });

      // رفع مشکل تصاویری که لود نمی‌شوند
      if (img.complete && img.naturalHeight === 0) {
        console.warn('Image failed to load, attempting reload:', img.src);
        const originalSrc = img.src;
        img.src = '';
        setTimeout(() => {
          img.src = originalSrc;
        }, 100);
      }
    });
  }

  // رفع مشکل عدم نمایش media در Shadow DOM
  function fixMediaDisplay() {
    // جستجوی تمام shadow roots
    const allElements = document.querySelectorAll('*');

    allElements.forEach(element => {
      if (element.shadowRoot) {
        const shadowRoot = element.shadowRoot;

        // رفع مشکل audio elements
        shadowRoot.querySelectorAll('audio').forEach(audio => {
          audio.controls = true;
          audio.style.display = 'block';
          audio.style.width = '100%';
          console.log('Audio controls enabled in shadow root:', audio.src);
        });

        // رفع مشکل image elements
        shadowRoot.querySelectorAll('img').forEach(img => {
          img.style.display = 'inline-block';
          img.style.maxWidth = '100%';
          console.log('Image display fixed in shadow root:', img.src);
        });

        // رفع مشکل video elements
        shadowRoot.querySelectorAll('video').forEach(video => {
          video.controls = true;
          video.style.display = 'block';
          video.style.width = '100%';
          console.log('Video controls enabled in shadow root:', video.src);
        });
      }
    });
  }

  // اینترسپت کلیک‌های داخل Shadow DOM
  function interceptShadowClicks() {
    document.addEventListener('click', function(e) {
      // بررسی اگر کلیک در Shadow DOM اتفاق افتاده
      const path = e.composedPath();

      for (const element of path) {
        // بررسی audio
        if (element.tagName === 'AUDIO') {
          console.log('Audio element clicked in shadow DOM');
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('shadowAudioInteraction', {
              src: element.src,
              paused: element.paused,
              currentTime: element.currentTime,
              duration: element.duration
            }).catch(err => console.error(err));
          }
        }

        // بررسی image
        if (element.tagName === 'IMG') {
          console.log('Image clicked in shadow DOM');
          if (window.flutter_inappwebview) {
            window.flutter_inappwebview.callHandler('shadowImageInteraction', {
              src: element.src,
              alt: element.alt,
              width: element.width,
              height: element.height
            }).catch(err => console.error(err));
          }
        }

        // بررسی دکمه‌های پخش
        if (element.tagName === 'BUTTON' &&
            (element.className.includes('play') ||
             element.getAttribute('aria-label')?.toLowerCase().includes('play'))) {
          console.log('Play button clicked in shadow DOM');
        }
      }
    }, true);
  }

  // اجرای دوره‌ای handlers
  function periodicUpdate() {
    if (detectIlaChat()) {
      handleAudioButtons();
      handleImages();
      fixMediaDisplay();
    }
  }

  // Initialize
  function init() {
    console.log('Initializing ILA Chat Helper...');

    // اجرای اولیه
    periodicUpdate();

    // نصب کلیک interceptor
    interceptShadowClicks();

    // اجرای دوره‌ای (هر 2 ثانیه)
    setInterval(periodicUpdate, 2000);

    // Observer برای تغییرات DOM
    const observer = new MutationObserver(() => {
      periodicUpdate();
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['src', 'class', 'id']
    });

    console.log('ILA Chat Helper ready!');
  }

  // شروع
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();
