/**
 * Shadow DOM Media Interceptor
 * این اسکریپت برای اینترسپت و مدیریت فایل‌های صوتی و تصویری در Shadow DOM طراحی شده است
 * برای استفاده در ila chat و سایر سیستم‌های چت که از Shadow DOM استفاده می‌کنند
 */

(function() {
  'use strict';
  
  console.log('Shadow DOM Interceptor initialized');
  
  // تنظیمات
  const CONFIG = {
    checkInterval: 1000, // بررسی هر 1 ثانیه
    maxRetries: 60, // حداکثر 60 بار تلاش (1 دقیقه)
    selectors: {
      shadowHosts: '*', // همه عناصر را بررسی کن
      audio: 'audio',
      image: 'img',
      video: 'video',
      mediaContainers: '[class*="chat"], [class*="message"], [id*="chat"], [id*="message"], [class*="ila"]'
    }
  };
  
  // ذخیره URLهای blob برای جلوگیری از پردازش مجدد
  const processedBlobUrls = new Set();
  
  // ذخیره observers برای cleanup
  const observers = new Set();
  
  /**
   * پیدا کردن تمام Shadow Roots در صفحه
   */
  function findAllShadowRoots(root = document.body) {
    const shadowRoots = [];
    
    function traverse(node) {
      if (!node) return;
      
      // بررسی اگر این node یک shadowRoot دارد
      if (node.shadowRoot) {
        shadowRoots.push(node.shadowRoot);
        console.log('Shadow root found:', node.tagName, node.className);
      }
      
      // بررسی فرزندان
      if (node.children) {
        for (let child of node.children) {
          traverse(child);
        }
      }
    }
    
    traverse(root);
    return shadowRoots;
  }
  
  /**
   * تبدیل blob URL به base64
   */
  async function blobUrlToBase64(blobUrl) {
    try {
      const response = await fetch(blobUrl);
      const blob = await response.blob();
      
      return new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onloadend = () => resolve(reader.result);
        reader.onerror = reject;
        reader.readAsDataURL(blob);
      });
    } catch (error) {
      console.error('Error converting blob to base64:', error);
      return null;
    }
  }
  
  /**
   * ارسال اطلاعات media به Flutter
   */
  function sendMediaToFlutter(type, url, base64Data, element) {
    if (!window.flutter_inappwebview) {
      console.warn('flutter_inappwebview not available');
      return;
    }
    
    const mediaInfo = {
      type: type,
      url: url,
      base64: base64Data,
      timestamp: Date.now(),
      elementInfo: {
        tagName: element.tagName,
        className: element.className,
        id: element.id
      }
    };
    
    window.flutter_inappwebview.callHandler('shadowMediaDetected', mediaInfo)
      .then(() => console.log(`Media sent to Flutter: ${type} - ${url}`))
      .catch(err => console.error('Error sending to Flutter:', err));
  }
  
  /**
   * پردازش عنصر audio
   */
  async function processAudioElement(audioElement) {
    const src = audioElement.src || audioElement.currentSrc;
    
    if (!src || processedBlobUrls.has(src)) {
      return;
    }
    
    console.log('Processing audio element:', src);
    processedBlobUrls.add(src);
    
    // اینترسپت رویداد play
    audioElement.addEventListener('play', async function(e) {
      console.log('Audio play intercepted:', src);
      
      if (src.startsWith('blob:')) {
        const base64 = await blobUrlToBase64(src);
        if (base64) {
          sendMediaToFlutter('audio', src, base64, audioElement);
        }
      } else {
        sendMediaToFlutter('audio', src, null, audioElement);
      }
    }, { once: false });
    
    // اینترسپت رویداد loadeddata
    audioElement.addEventListener('loadeddata', async function(e) {
      console.log('Audio loaded:', src);
      
      if (src.startsWith('blob:')) {
        const base64 = await blobUrlToBase64(src);
        if (base64) {
          sendMediaToFlutter('audio_loaded', src, base64, audioElement);
        }
      }
    }, { once: true });
    
    // بررسی src attribute changes
    const srcObserver = new MutationObserver(async (mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === 'attributes' && mutation.attributeName === 'src') {
          const newSrc = audioElement.src;
          if (newSrc && !processedBlobUrls.has(newSrc)) {
            console.log('Audio src changed:', newSrc);
            processedBlobUrls.add(newSrc);
            
            if (newSrc.startsWith('blob:')) {
              const base64 = await blobUrlToBase64(newSrc);
              if (base64) {
                sendMediaToFlutter('audio', newSrc, base64, audioElement);
              }
            }
          }
        }
      }
    });
    
    srcObserver.observe(audioElement, { attributes: true, attributeFilter: ['src'] });
    observers.add(srcObserver);
  }
  
  /**
   * پردازش عنصر image
   */
  async function processImageElement(imgElement) {
    const src = imgElement.src || imgElement.currentSrc;
    
    if (!src || processedBlobUrls.has(src)) {
      return;
    }
    
    console.log('Processing image element:', src);
    processedBlobUrls.add(src);
    
    // اینترسپت رویداد click
    imgElement.addEventListener('click', async function(e) {
      console.log('Image click intercepted:', src);
      
      if (src.startsWith('blob:')) {
        const base64 = await blobUrlToBase64(src);
        if (base64) {
          sendMediaToFlutter('image', src, base64, imgElement);
        }
      } else {
        sendMediaToFlutter('image', src, null, imgElement);
      }
    }, { once: false });
    
    // اینترسپت رویداد load
    imgElement.addEventListener('load', async function(e) {
      console.log('Image loaded:', src);
      
      if (src.startsWith('blob:')) {
        const base64 = await blobUrlToBase64(src);
        if (base64) {
          sendMediaToFlutter('image_loaded', src, base64, imgElement);
        }
      }
    }, { once: true });
  }
  
  /**
   * پردازش عنصر video
   */
  async function processVideoElement(videoElement) {
    const src = videoElement.src || videoElement.currentSrc;
    
    if (!src || processedBlobUrls.has(src)) {
      return;
    }
    
    console.log('Processing video element:', src);
    processedBlobUrls.add(src);
    
    // اینترسپت رویداد play
    videoElement.addEventListener('play', async function(e) {
      console.log('Video play intercepted:', src);
      
      if (src.startsWith('blob:')) {
        const base64 = await blobUrlToBase64(src);
        if (base64) {
          sendMediaToFlutter('video', src, base64, videoElement);
        }
      } else {
        sendMediaToFlutter('video', src, null, videoElement);
      }
    }, { once: false });
  }
  
  /**
   * پردازش تمام media elements در یک root
   */
  function processMediaInRoot(root) {
    // پردازش audio elements
    const audioElements = root.querySelectorAll(CONFIG.selectors.audio);
    audioElements.forEach(audio => {
      try {
        processAudioElement(audio);
      } catch (error) {
        console.error('Error processing audio:', error);
      }
    });
    
    // پردازش image elements
    const imageElements = root.querySelectorAll(CONFIG.selectors.image);
    imageElements.forEach(img => {
      try {
        processImageElement(img);
      } catch (error) {
        console.error('Error processing image:', error);
      }
    });
    
    // پردازش video elements
    const videoElements = root.querySelectorAll(CONFIG.selectors.video);
    videoElements.forEach(video => {
      try {
        processVideoElement(video);
      } catch (error) {
        console.error('Error processing video:', error);
      }
    });
  }
  
  /**
   * نصب MutationObserver روی یک root
   */
  function observeRoot(root) {
    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === 'childList') {
          mutation.addedNodes.forEach(node => {
            if (node.nodeType === Node.ELEMENT_NODE) {
              // بررسی اگر خود node یک media element است
              if (node.tagName === 'AUDIO') {
                processAudioElement(node);
              } else if (node.tagName === 'IMG') {
                processImageElement(node);
              } else if (node.tagName === 'VIDEO') {
                processVideoElement(node);
              }
              
              // بررسی media elements داخل node
              if (node.querySelectorAll) {
                processMediaInRoot(node);
              }
              
              // بررسی اگر shadowRoot جدید اضافه شده
              if (node.shadowRoot) {
                console.log('New shadow root detected in mutation');
                setupShadowRootObserver(node.shadowRoot);
              }
            }
          });
        }
      }
    });
    
    observer.observe(root, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['src']
    });
    
    observers.add(observer);
    console.log('Observer installed on root');
  }
  
  /**
   * نصب observer روی shadow root
   */
  function setupShadowRootObserver(shadowRoot) {
    // پردازش media های موجود
    processMediaInRoot(shadowRoot);
    
    // نصب observer برای تغییرات آینده
    observeRoot(shadowRoot);
  }
  
  /**
   * جستجو و نصب observer روی تمام shadow roots
   */
  function scanAndObserveShadowRoots() {
    const shadowRoots = findAllShadowRoots();
    
    console.log(`Found ${shadowRoots.length} shadow root(s)`);
    
    shadowRoots.forEach(shadowRoot => {
      setupShadowRootObserver(shadowRoot);
    });
    
    // پردازش media در main document
    processMediaInRoot(document);
  }
  
  /**
   * نصب observer روی body برای شناسایی shadow roots جدید
   */
  function setupBodyObserver() {
    observeRoot(document.body);
    console.log('Body observer installed');
  }
  
  /**
   * شروع اسکن مداوم
   */
  function startContinuousScanning() {
    let scanCount = 0;
    
    const scanInterval = setInterval(() => {
      scanCount++;
      console.log(`Shadow DOM scan #${scanCount}`);
      scanAndObserveShadowRoots();
      
      if (scanCount >= CONFIG.maxRetries) {
        console.log('Max retries reached, stopping continuous scan');
        clearInterval(scanInterval);
      }
    }, CONFIG.checkInterval);
    
    // ذخیره برای cleanup
    window._shadowDomScanInterval = scanInterval;
  }
  
  /**
   * Cleanup function
   */
  function cleanup() {
    console.log('Cleaning up Shadow DOM Interceptor');
    
    // پاک کردن interval
    if (window._shadowDomScanInterval) {
      clearInterval(window._shadowDomScanInterval);
    }
    
    // disconnect observers
    observers.forEach(observer => observer.disconnect());
    observers.clear();
    
    // پاک کردن processed URLs
    processedBlobUrls.clear();
  }
  
  // ثبت cleanup در window
  window._shadowDomInterceptorCleanup = cleanup;
  
  /**
   * Initialize
   */
  function init() {
    console.log('Initializing Shadow DOM Interceptor...');
    
    // اسکن اولیه
    scanAndObserveShadowRoots();
    
    // نصب observer روی body
    setupBodyObserver();
    
    // شروع اسکن مداوم
    startContinuousScanning();
    
    console.log('Shadow DOM Interceptor ready!');
  }
  
  // شروع پس از بارگذاری کامل صفحه
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    // صفحه قبلاً بارگذاری شده
    init();
  }
  
  // اجرای مجدد در صورت تغییر location
  let lastUrl = location.href;
  new MutationObserver(() => {
    const url = location.href;
    if (url !== lastUrl) {
      lastUrl = url;
      console.log('URL changed, re-initializing...');
      cleanup();
      setTimeout(init, 500);
    }
  }).observe(document, { subtree: true, childList: true });
  
})();
