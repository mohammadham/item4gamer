(function(window) {
  console.log('Main polyfill starting');

  // Skip if native Notification exists
  if (window.Notification && window.Notification.prototype) {
    console.log('Native Notification API found, skipping polyfill');
    return;
  }

  // Check secure context
  if (!window.isSecureContext) {
    console.log('Not a secure context, notifications unavailable');
    return;
  }

  // Ensure flutter_inappwebview is available
  if (!window.flutter_inappwebview) {
    console.error('flutter_inappwebview not available');
    return;
  }

  // Store notifications
  window._flutter_inappweview_notifications = {};
  window._flutter_inappweview_notification_id_autoincrement = 0;

  // Define Notification class
  class Notification extends EventTarget {
    constructor(title, options = {}) {
      super();
      this.id = window._flutter_inappweview_notification_id_autoincrement++;
      this.title = title;
      this.body = options.body || '';
      this.actions = options.actions || [];
      this.badge = options.badge;
      this.data = options.data;
      this.dir = options.dir || 'auto';
      this.icon = options.icon;
      this.image = options.image;
      this.lang = options.lang;
      this.renotify = options.renotify || false;
      this.requireInteraction = options.requireInteraction || false;
      this.silent = options.silent || false;
      this.tag = options.tag || '';
      this.timestamp = options.timestamp || Date.now();
      this.vibrate = options.vibrate || [];

      // Store notification
      window._flutter_inappweview_notifications[this.id] = this;

      // Call Flutter to show notification
      window.flutter_inappwebview.callHandler('Notification.show', {
        id: this.id,
        title: this.title,
        body: this.body,
        actions: this.actions,
        badge: this.badge,
        data: this.data,
        dir: this.dir,
        icon: this.icon,
        image: this.image,
        lang: this.lang,
        renotify: this.renotify,
        requireInteraction: this.requireInteraction,
        silent: this.silent,
        tag: this.tag,
        timestamp: this.timestamp,
        vibrate: this.vibrate
      }).catch(function(error) {
        console.error('Error showing notification:', error);
      });

      console.log('Notification created with id:', this.id);
    }

    close() {
      window.flutter_inappwebview.callHandler('Notification.close', this.id)
        .catch(function(error) {
          console.error('Error closing notification:', error);
        });
      delete window._flutter_inappweview_notifications[this.id];
    }
  }

  // Static permission property
  Notification._permission = 'default';
  Object.defineProperty(Notification, 'permission', {
    get: function() {
      return Notification._permission;
    },
    enumerable: true
  });

  // Static requestPermission method
  Notification.requestPermission = function(callback) {
    return window.flutter_inappwebview.callHandler('Notification.requestPermission')
      .then(function(permission) {
        Notification._permission = permission;
        if (callback) callback(permission);
        return permission;
      }).catch(function(error) {
        console.error('Error requesting permission:', error);
        return 'denied';
      });
  };

  // Override placeholder
  window.Notification = Notification;

  console.log('Main polyfill applied');
})(window);