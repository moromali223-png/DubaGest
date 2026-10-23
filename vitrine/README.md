# Vitrine Officielle & Portail PWA DubaGest

Ce portail web est la vitrine officielle et le hub de distribution PWA de **DubaGest**, conçu pour maximiser le taux de conversion, l'indexation SEO et l'installation instantanée de l'application sur **iPhone (Safari)**, **Android** et **Desktop**.

---

## 1. Caractéristiques Techniques

* **Performance extrême :** Poids total inférieur à 80 Ko, First Contentful Paint < 300ms sur réseau 3G/4G au Mali et en zone UEMOA.
* **100% Découplé :** La vitrine commerciale est indépendante du bundle lourd de l'application Flutter (CanvasKit/WASM), garantissant un temps de chargement instantané.
* **Moteur d'installation PWA adaptatif :**
  * **Sur iPhone / iPad (Safari) :** Modale pas-à-pas avec les icônes iOS (Partager $\rightarrow$ Sur l'écran d'accueil $\rightarrow$ Ajouter).
  * **Sur Android (Chrome/Edge/Samsung) :** Interception native de l'événement `beforeinstallprompt`, déclenchement de l'invite 1-clic et fallback avec guide de secours.
  * **Sur Ordinateur (PC / Mac) :** Détection de l'invite Chromium et accès web direct.
  * **Mode Autonome (Déjà installé) :** Détection de `display-mode: standalone` ou `navigator.standalone` pour transformer automatiquement les boutons en « Ouvrir DubaGest ».
* **SEO & Accessibilité :** Balises Open Graph complètes, Twitter Cards, balisage Schema.org `SoftwareApplication` et `FAQPage`, respect strict des contrastes WCAG AA.
* **Identité visuelle certifiée DubaGest :** Vert Émeraude (`#1E7E4E`), Ardoise Sombre (`#1A2522`), Menthe Douce (`#E8F5EE`).

---

## 2. Structure des Fichiers

```text
vitrine/
├── index.html           # Structure sémantique complète (Hero, Modules, Tarifs, PWA, FAQ, Contact)
├── manifest.json        # Manifeste PWA pour l'installation autonome sur écran d'accueil
├── sw.js                # Service Worker pour le cache et le fonctionnement hors-ligne
├── favicon.png          # Favicon officiel
├── css/
│   └── style.css        # Design system officiel, micro-animations et responsive mobile-first
├── js/
│   ├── config.js        # Configuration des URLs (App Flutter, APK, Play Store, Contact, Tarifs)
│   └── app.js           # Détection OS, gestionnaire PWA, modales et interactivité
├── icons/               # Icônes PWA (192x192, 512x512, standard et maskable)
└── assets/              # Logo officiel de marque DubaGest
```

---

## 3. Configuration des Environnements (`js/config.js`)

Pour adapter le portail selon votre environnement de déploiement (Local, Staging ou Production), modifiez simplement `vitrine/js/config.js` sans toucher au code applicatif :

```javascript
window.DUBAGEST_CONFIG = {
  // Adresse de l'application Flutter hébergée
  appUrl: 'https://app.dubagest.ml', // ou '/app' en reverse proxy
  
  // Téléchargement APK Android direct
  android: {
    apkUrl: 'https://downloads.dubagest.ml/dubagest-v1.0.0.apk',
    version: '1.0.0',
    taille: '18.4 Mo',
    datePublication: 'Octobre 2026',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=io.dubagest' // dès validation
  },

  // Contact & Support WhatsApp (Bamako, Mali)
  contact: {
    supportEmail: 'contact@dubagest.ml',
    whatsapp: '22370000000',
    telephone: '+223 70 00 00 00'
  }
};
```

---

## 4. Déploiement en Production

### Option A : Déploiement autonome (Cloudflare Pages, Vercel, Netlify)
Déployez simplement le dossier `vitrine/` en pointant la racine du domaine (ex. `https://dubagest.ml`). L'application Flutter peut être servie sur le sous-domaine `https://app.dubagest.ml`.

### Option B : Déploiement unifié avec Nginx / Caddy
Vous pouvez servir à la fois la vitrine à la racine `/` et la PWA Flutter sous `/app/` :

```nginx
server {
    server_name dubagest.ml www.dubagest.ml;
    listen 443 ssl http2;

    # Vitrine commerciale (chargement ultra-rapide)
    location / {
        root /var/www/dubagest/vitrine;
        try_files $uri $uri/ /index.html;
    }

    # Application métier Flutter PWA
    location /app/ {
        alias /var/www/dubagest/build/web/;
        try_files $uri $uri/ /app/index.html;
    }
}
```

---

## 5. Commandes de Test Local

Pour prévisualiser la vitrine localement :
```powershell
# Avec Python
python -m http.server 8089 --directory vitrine

# Ou avec Node.js
npx serve vitrine -p 8089
```
Accédez ensuite à `http://localhost:8089/`.
