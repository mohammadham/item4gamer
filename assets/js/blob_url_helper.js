/**
 * Blob URL Helper
 * کمک به مدیریت blob URLs در WebView
 */

(function() {
  'use strict';

  console.log('Blob URL Helper initialized');

  // اینترسپت XMLHttpRequest برای blob responses
  const originalOpen = XMLHttpRequest.prototype.open;
  const originalSend = XMLHttpRequest.prototype.send;

  XMLHttpRequest.prototype.open = function(method, url) {
    this._requestUrl = url;
    this._requestMethod = method;
    return originalOpen.apply(this, arguments);
  };

  XMLHttpRequest.prototype.send = function() {
    const xhr = this;

    this.addEventListener('load', function() {
      // بررسی اگر response یک blob است
      if (xhr.responseType === 'blob' && xhr.response) {
        console.log('Blob response detected:', xhr._requestUrl);

        // ارسال به Flutter
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('blobResponseDetected', {
            url: xhr._requestUrl,
            method: xhr._requestMethod,
            status: xhr.status,
            contentType: xhr.getResponseHeader('Content-Type')
          }).catch(err => console.error('Error sending blob info:', err));
        }
      }
    });

    return originalSend.apply(this, arguments);
  };

  // اینترسپت fetch برای blob responses
  const originalFetch = window.fetch;
  window.fetch = function(url, options) {
    return originalFetch.apply(this, arguments).then(response => {
      // کلون response برای خواندن بدون مصرف original stream
      const clonedResponse = response.clone();

      // بررسی Content-Type
      const contentType = response.headers.get('Content-Type');
      if (contentType && (
        contentType.includes('audio/') ||
        contentType.includes('video/') ||
        contentType.includes('image/')
      )) {
        console.log('Media fetch detected:', url, contentType);

        // ارسال به Flutter
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('mediaFetchDetected', {
            url: url.toString(),
            contentType: contentType,
            ok: response.ok,
            status: response.status
          }).catch(err => console.error('Error sending media fetch info:', err));
        }
      }

      return response;
    });
  };

  // اینترسپت URL.createObjectURL
  const originalCreateObjectURL = URL.createObjectURL;
  URL.createObjectURL = function(blob) {
    const blobUrl = originalCreateObjectURL.apply(this, arguments);

    console.log('Blob URL created:', blobUrl, 'Type:', blob.type, 'Size:', blob.size);

    // ارسال به Flutter
    if (window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('blobUrlCreated', {
        url: blobUrl,
        type: blob.type,
        size: blob.size
      }).catch(err => console.error('Error sending blob URL info:', err));
    }

    return blobUrl;
  };

  // اینترسپت URL.revokeObjectURL
  const originalRevokeObjectURL = URL.revokeObjectURL;
  URL.revokeObjectURL = function(blobUrl) {
    console.log('Blob URL revoked:', blobUrl);

    // ارسال به Flutter
    if (window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('blobUrlRevoked', {
        url: blobUrl
      }).catch(err => console.error('Error sending blob URL revoke info:', err));
    }

    return originalRevokeObjectURL.apply(this, arguments);
  };

  console.log('Blob URL Helper ready!');
})();
