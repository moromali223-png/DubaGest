/**
 * DubaGest — Contrôleur Frontend & Gestionnaire d'Installation PWA
 */

(function () {
  'use strict';

  // État PWA global
  let deferredInstallPrompt = null;
  const config = window.DUBAGEST_CONFIG;

  // Détections environnementales
  const isIOS = () => {
    return (
      /iPad|iPhone|iPod/.test(navigator.userAgent) ||
      (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
    );
  };

  const isIOSSafari = () => {
    const ua = navigator.userAgent;
    const isIOSDevice = isIOS();
    const isWebKit = /WebKit/.test(ua);
    const isOtherIOSBrowser = /CriOS|FxiOS|OPiOS|EdgiOS|DuckDuckGo/.test(ua);
    return isIOSDevice && isWebKit && !isOtherIOSBrowser;
  };

  const isAndroid = () => {
    return /Android/i.test(navigator.userAgent);
  };

  const isStandalone = () => {
    return (
      window.matchMedia('(display-mode: standalone)').matches ||
      window.navigator.standalone === true ||
      document.referrer.includes('android-app://')
    );
  };

  // Enregistrement du Service Worker
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker
        .register('./sw.js')
        .then((reg) => {
          console.log('[DubaGest] Service Worker actif. Scope :', reg.scope);
        })
        .catch((err) => {
          console.warn('[DubaGest] Erreur enregistrement SW :', err);
        });
    });
  }

  // Initialisation au chargement du DOM
  document.addEventListener('DOMContentLoaded', () => {
    initAppLinks();
    initPwaInstall();
    initPlans();
    initFaqAccordion();
    initMobileNav();
    initScrollHeader();
  });

  /**
   * Configure les liens vers l'application Flutter et les stores
   */
  function initAppLinks() {
    // Boutons de connexion / ouverture directe
    const loginButtons = document.querySelectorAll('.action-login');
    loginButtons.forEach((btn) => {
      btn.href = config.loginUrl;
      btn.addEventListener('click', (e) => {
        // Si besoin de tracking analytique respectueux de la vie privée
      });
    });

    // Boutons APK Android
    const apkButtons = document.querySelectorAll('.action-apk');
    apkButtons.forEach((btn) => {
      const targetUrl = config.android.apkUrl || '/downloads/DubaGest-Android.apk';
      btn.href = targetUrl;
      btn.setAttribute('download', config.android.nomFichier || 'DubaGest-Android.apk');
      btn.removeAttribute('target');
      btn.removeAttribute('rel');
      btn.addEventListener('click', (e) => {
        if (!config.android.estDisponible) {
          e.preventDefault();
          showToast('Le fichier APK est temporairement en cours de mise à jour. Veuillez réessayer dans quelques instants.', 'warning');
          return;
        }
        showToast(`Téléchargement de l'APK officiel DubaGest (${config.android.taille || '39 Mo'}) en cours...`, 'info');
      });
    });

    // Boutons Google Play
    const playButtons = document.querySelectorAll('.action-playstore');
    playButtons.forEach((btn) => {
      if (config.android.playStoreUrl) {
        btn.href = config.android.playStoreUrl;
      } else {
        btn.addEventListener('click', (e) => {
          e.preventDefault();
          showToast(
            'DubaGest sur Google Play Store est en cours de validation. Vous pouvez installer la version PWA immédiatement !',
            'info'
          );
        });
      }
    });

    // Numéros WhatsApp et Contact
    const waButtons = document.querySelectorAll('.action-whatsapp');
    waButtons.forEach((btn) => {
      btn.href = `https://wa.me/${config.contact.whatsapp}?text=${encodeURIComponent(
        'Bonjour DubaGest, je souhaite avoir des informations sur votre application de gestion.'
      )}`;
    });

    const emailButtons = document.querySelectorAll('.action-email');
    emailButtons.forEach((btn) => {
      btn.href = `mailto:${config.contact.supportEmail}`;
      if (btn.classList.contains('text-replace')) {
        btn.textContent = config.contact.supportEmail;
      }
    });
  }

  /**
   * Moteur intelligent d'installation PWA
   */
  function initPwaInstall() {
    const heroInstallBtn = document.getElementById('hero-install-btn');
    const navInstallBtn = document.getElementById('nav-install-btn');
    const pwaSectionBtn = document.getElementById('pwa-section-btn');
    const installBtns = [heroInstallBtn, navInstallBtn, pwaSectionBtn].filter(Boolean);

    // 1. Détection du mode Déjà installé (Standalone)
    if (isStandalone()) {
      installBtns.forEach((btn) => {
        btn.innerHTML = `
          <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
          </svg>
          <span>Ouvrir DubaGest</span>
        `;
        btn.classList.add('btn-installed');
        btn.addEventListener('click', () => {
          window.location.href = config.appUrl;
        });
      });

      const installStatusBanner = document.getElementById('install-status-badge');
      if (installStatusBanner) {
        installStatusBanner.textContent = 'Application installée en mode autonome';
        installStatusBanner.classList.add('badge-success');
      }
      return;
    }

    // Adaptation proactive des boutons selon le terminal détecté
    if (isIOS()) {
      if (heroInstallBtn) {
        const span = heroInstallBtn.querySelector('span');
        if (span) span.textContent = 'Installer sur iPhone (Safari)';
      }
      if (navInstallBtn) {
        const span = navInstallBtn.querySelector('span');
        if (span) span.textContent = 'iPhone PWA';
      }
    } else if (isAndroid()) {
      if (heroInstallBtn) {
        const span = heroInstallBtn.querySelector('span');
        if (span) span.textContent = 'Installer sur Android';
      }
    }

    // 2. Écoute de l'événement natif Android / Desktop Chromium
    window.addEventListener('beforeinstallprompt', (e) => {
      e.preventDefault();
      deferredInstallPrompt = e;
      console.log('[DubaGest] beforeinstallprompt capturé.');

      installBtns.forEach((btn) => {
        btn.classList.remove('btn-disabled');
        btn.title = 'Installer directement sur votre appareil';
      });

      const installStatusBadge = document.getElementById('install-status-badge');
      if (installStatusBadge) {
        installStatusBadge.textContent = 'Installation 1 clic prête';
        installStatusBadge.classList.add('badge-ready');
      }
    });

    // 3. Écoute de la fin d'installation
    window.addEventListener('appinstalled', () => {
      deferredInstallPrompt = null;
      showToast('Félicitations ! DubaGest est maintenant installé sur votre écran d\'accueil.', 'success');
      installBtns.forEach((btn) => {
        btn.innerHTML = `
          <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
          </svg>
          <span>Ouvrir l'application</span>
        `;
        btn.onclick = () => {
          window.location.href = config.appUrl;
        };
      });
    });

    // 4. Gestion du clic sur les boutons d'installation
    installBtns.forEach((btn) => {
      btn.href = config.appUrl;
      btn.setAttribute('target', '_blank');
      btn.setAttribute('rel', 'noopener noreferrer');
      btn.addEventListener('click', (e) => {
        handleInstallClick(e);
      });
    });
  }

  /**
   * Action au clic sur le bouton principal d'installation
   */
  function handleInstallClick(e) {
    // A. Utilisateur avec invite native Chrome / Edge / Android
    if (deferredInstallPrompt) {
      if (e) e.preventDefault();
      deferredInstallPrompt.prompt();
      deferredInstallPrompt.userChoice.then((choiceResult) => {
        if (choiceResult.outcome === 'accepted') {
          console.log('[DubaGest] L\'utilisateur a accepté l\'installation');
          showToast('Installation en cours...', 'success');
        }
        deferredInstallPrompt = null;
      });
      return;
    }

    // B. Utilisateur sur iPhone ou iPad
    if (isIOS()) {
      if (e) e.preventDefault();
      if (isIOSSafari()) {
        openModal('modal-ios-safari');
      } else {
        openModal('modal-ios-other');
      }
      return;
    }

    // C. Sur ordinateur ou Android : navigation naturelle vers config.appUrl (pas de popup bloquée)
    showToast('Ouverture de DubaGest (PWA)...', 'info');
  }

  /**
   * Génération dynamique des cartes de tarifs depuis config.js (données vérifiées)
   */
  function initPlans() {
    const plansContainer = document.getElementById('plans-grid');
    if (!plansContainer || !config.plans) return;

    plansContainer.innerHTML = '';

    config.plans.forEach((plan) => {
      const card = document.createElement('div');
      card.className = `plan-card ${plan.populaire ? 'plan-featured' : ''}`;

      const formattedPrice = new Intl.NumberFormat('fr-FR').format(plan.prixMensuel);

      card.innerHTML = `
        ${plan.badge ? `<div class="plan-badge">${plan.badge}</div>` : ''}
        <div class="plan-header">
          <h3 class="plan-title">${plan.nom}</h3>
          <p class="plan-desc">${plan.description}</p>
        </div>
        <div class="plan-price-wrap">
          <span class="plan-price">${formattedPrice}</span>
          <span class="plan-currency">${plan.devise}</span>
          <span class="plan-period">/ mois</span>
        </div>
        <div class="plan-quotas">
          <div class="quota-item">
            <svg class="quota-icon" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
            </svg>
            <span><strong>${plan.maxActivites}</strong> ${plan.maxActivites > 1 ? 'activités combinables' : 'activité au choix'}</span>
          </div>
          <div class="quota-item">
            <svg class="quota-icon" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
            </svg>
            <span><strong>${plan.maxPerimetres}</strong> ${typeof plan.maxPerimetres === 'number' && plan.maxPerimetres > 1 ? 'boutiques / agences' : 'boutique / agence'}</span>
          </div>
          <div class="quota-item">
            <svg class="quota-icon" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
            </svg>
            <span><strong>${plan.maxUtilisateursCommerce}</strong> ${typeof plan.maxUtilisateursCommerce === 'number' ? 'utilisateurs (Commerce)' : 'utilisateurs'}</span>
          </div>
        </div>
        <hr class="plan-divider" />
        <ul class="plan-features">
          ${plan.fonctionnalites.map((f) => `<li><span class="check-icon">✓</span> <span>${f}</span></li>`).join('')}
        </ul>
        <div class="plan-action">
          <a href="${config.loginUrl}" class="btn ${plan.populaire ? 'btn-primary' : 'btn-outline'} btn-block">
            Choisir la formule ${plan.nom}
          </a>
        </div>
      `;

      plansContainer.appendChild(card);
    });
  }

  /**
   * Accordéons interactifs pour la FAQ
   */
  function initFaqAccordion() {
    const faqItems = document.querySelectorAll('.faq-item');
    faqItems.forEach((item) => {
      const question = item.querySelector('.faq-question');
      question.addEventListener('click', () => {
        const isOpen = item.classList.contains('active');
        // Ferme les autres pour un confort de lecture
        faqItems.forEach((other) => other.classList.remove('active'));
        if (!isOpen) {
          item.classList.add('active');
        }
      });
    });
  }

  /**
   * Menu mobile responsive
   */
  function initMobileNav() {
    const burger = document.getElementById('mobile-nav-toggle');
    const navMenu = document.getElementById('nav-menu');
    if (!burger || !navMenu) return;

    burger.addEventListener('click', () => {
      const expanded = burger.getAttribute('aria-expanded') === 'true';
      burger.setAttribute('aria-expanded', !expanded);
      navMenu.classList.toggle('nav-open');
    });

    // Fermeture automatique au clic sur un lien
    navMenu.querySelectorAll('a').forEach((link) => {
      link.addEventListener('click', () => {
        burger.setAttribute('aria-expanded', 'false');
        navMenu.classList.remove('nav-open');
      });
    });
  }

  /**
   * Effet d'élévation de la navbar lors du scroll
   */
  function initScrollHeader() {
    const header = document.querySelector('.site-header');
    if (!header) return;

    window.addEventListener(
      'scroll',
      () => {
        if (window.scrollY > 20) {
          header.classList.add('header-scrolled');
        } else {
          header.classList.remove('header-scrolled');
        }
      },
      { passive: true }
    );
  }

  /**
   * Modales d'aide et d'instructions
   */
  window.openModal = function (modalId) {
    const modal = document.getElementById(modalId);
    if (!modal) return;
    modal.classList.add('modal-visible');
    document.body.style.overflow = 'hidden';
  };

  window.closeModal = function (modalId) {
    const modal = document.getElementById(modalId);
    if (!modal) return;
    modal.classList.remove('modal-visible');
    document.body.style.overflow = '';
  };

  // Fermeture des modales au clic sur le fond sombre
  document.addEventListener('click', (e) => {
    if (e.target.classList.contains('modal-overlay')) {
      e.target.classList.remove('modal-visible');
      document.body.style.overflow = '';
    }
  });

  // Fermeture avec la touche Échap
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      const visibleModal = document.querySelector('.modal-overlay.modal-visible');
      if (visibleModal) {
        visibleModal.classList.remove('modal-visible');
        document.body.style.overflow = '';
      }
    }
  });

  /**
   * Notification Toast non intrusive
   */
  function showToast(message, type = 'info') {
    let container = document.getElementById('toast-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'toast-container';
      container.className = 'toast-container';
      document.body.appendChild(container);
    }

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.innerHTML = `
      <div class="toast-content">${message}</div>
      <button class="toast-close" onclick="this.parentElement.remove()">&times;</button>
    `;

    container.appendChild(toast);

    setTimeout(() => {
      toast.classList.add('toast-fade');
      setTimeout(() => toast.remove(), 400);
    }, 4500);
  }
})();
