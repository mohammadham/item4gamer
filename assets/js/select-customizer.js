// select-customizer.js
const styleSelectElements = () => {
  document.querySelectorAll('select').forEach(select => {
    // Hide original select
    select.style.display = 'none';

    // Create custom wrapper
    const wrapper = document.createElement('div');
    wrapper.className = 'custom-select-wrapper';
    wrapper.innerHTML = `
      <div class="custom-select-btn">
        <span class="selected-text">${select.options[select.selectedIndex].text}</span>
        <div class="arrow-icon">▼</div>
      </div>
    `;

    // Create modal for options
    const modal = document.createElement('div');
    modal.className = 'custom-select-modal';
    let optionsHTML = '';
    for (let i = 0; i < select.options.length; i++) {
      optionsHTML += `<div class="option" data-value="${select.options[i].value}">${select.options[i].text}</div>`;
    }
    modal.innerHTML = optionsHTML;

    wrapper.appendChild(modal);
    select.parentNode.insertBefore(wrapper, select.nextSibling);

    // Event listeners
    wrapper.querySelector('.custom-select-btn').addEventListener('click', () => {
      modal.style.display = modal.style.display === 'block' ? 'none' : 'block';
    });

    modal.querySelectorAll('.option').forEach(option => {
      option.addEventListener('click', () => {
        const value = option.getAttribute('data-value');
        select.value = value;
        select.dispatchEvent(new Event('change'));
        wrapper.querySelector('.selected-text').textContent = option.textContent;
        modal.style.display = 'none';
      });
    });
  });
};

// Platform-specific styling
const applyPlatformStyle = () => {
  const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
  const platformClass = isIOS ? 'ios-style' : 'android-style';

  document.body.classList.add(platformClass);
  document.head.insertAdjacentHTML('beforeend', `
    <style>
      .custom-select-wrapper {
        position: relative;
        width: 100%;
      }
      .custom-select-btn {
        padding: 12px;
        border: 1px solid #ddd;
        border-radius: 8px;
        background: white;
        cursor: pointer;
        display: flex;
        justify-content: space-between;
        align-items: center;
      }
      .arrow-icon {
        font-size: 14px;
      }
      .custom-select-modal {
        display: none;
        position: absolute;
        width: 100%;
        background: white;
        border-radius: 8px;
        box-shadow: 0 2px 10px rgba(0,0,0,0.2);
        z-index: 100;
      }
      .option {
        padding: 12px;
        cursor: pointer;
        border-bottom: 1px solid #eee;
      }
      .option:hover {
        background-color: #f5f5f5;
      }
      
      /* iOS-specific styles */
      .ios-style .custom-select-btn {
        padding: 14px;
        box-shadow: 0 1px 2px rgba(0,0,0,0.1);
      }
      .ios-style .arrow-icon {
        transform: rotate(90deg);
      }
      
      /* Android-specific styles */
      .android-style .custom-select-btn {
        border: none;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      }
      .android-style .arrow-icon {
        font-weight: bold;
      }
    </style>
  `);
};

// Initialize after page load
window.addEventListener('load', () => {
  applyPlatformStyle();
  styleSelectElements();
  
  // Observe DOM changes for dynamically added selects
  const observer = new MutationObserver(styleSelectElements);
  observer.observe(document.body, { childList: true, subtree: true });
});