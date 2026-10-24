/**
 * Configuration de la Vitrine et du Portail DubaGest
 * Personnalisable sans modifier le code de l'application.
 */
window.DUBAGEST_CONFIG = {
  // Nom officiel
  appName: 'DubaGest',
  tagline: 'La gestion simple de votre activité.',
  description: 'Gestion Commerce, Services et Immobilier — mobile-first, 100% hors-ligne & synchronisé.',
  
  // URL de l'application métier Flutter (PWA)
  // En local : 'http://localhost:3000'
  // En production : 'https://dubagest-app.pages.dev'
  appUrl: (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1')
    ? 'http://localhost:3000'
    : 'https://dubagest-app.pages.dev',
    
  // URL directe de connexion
  get loginUrl() {
    return this.appUrl.endsWith('/') ? `${this.appUrl}login` : `${this.appUrl}/login`;
  },

  // Téléchargement Android APK officiel
  android: {
    // URL directe du fichier APK officiel
    apkUrl: 'https://github.com/moromali223-png/DubaGest/releases/download/v1.0.0/dubagest-release.apk', 
    version: '1.0.0',
    taille: '106.6 Mo',
    datePublication: 'Octobre 2026',
    estDisponible: true,
    // Google Play Store (mettre l'URL dès publication)
    playStoreUrl: null // ex: 'https://play.google.com/store/apps/details?id=io.dubagest'
  },

  // iOS App Store
  ios: {
    appStoreUrl: null, // PWA Safari prioritaire en V1
    pwaRecommandee: true
  },

  // Coordonnées et support (Bamako, Mali / Espace UEMOA)
  contact: {
    supportEmail: 'contact@dubagest.ml',
    commercialEmail: 'ventes@dubagest.ml',
    telephone: '+223 70 00 00 00',
    whatsapp: '22370000000', // sans '+' pour wa.me
    adresse: 'Bamako, Mali'
  },

  // Formules réelles issues de la base de données
  plans: [
    {
      code: 'NORMAL',
      nom: 'Normal',
      prixMensuel: 1000,
      devise: 'FCFA',
      description: 'Idéal pour démarrer avec une seule activité et une petite équipe.',
      maxActivites: 1,
      maxPerimetres: 1,
      maxUtilisateursCommerce: 3,
      badge: 'Démarrage',
      populaire: false,
      fonctionnalites: [
        '1 activité au choix (Commerce OU Services OU Immobilier)',
        '1 boutique ou agence',
        'Jusqu\'à 3 utilisateurs (Commerce) ou 1 utilisateur (Services / Immobilier)',
        'Fonctionnement 100% hors-ligne complet',
        'Gestion des stocks, ventes et dépenses',
        'Génération de factures & devis PDF'
      ]
    },
    {
      code: 'MOYEN',
      nom: 'Moyen',
      prixMensuel: 2000,
      devise: 'FCFA',
      description: 'Pour les entreprises combinant deux activités avec plusieurs boutiques.',
      maxActivites: 2,
      maxPerimetres: 2,
      maxUtilisateursCommerce: 7,
      badge: 'Le plus choisi',
      populaire: true,
      fonctionnalites: [
        '2 activités combinables (ex. Commerce + Services)',
        'Jusqu\'à 2 boutiques ou points de vente',
        'Jusqu\'à 7 utilisateurs (Commerce)',
        'Rôles d\'équipe avancés (Vendeur, Gestionnaire stock, Superviseur)',
        'Dossiers de dettes & créances clients/fournisseurs',
        'Analyses de marges et intelligence commerciale'
      ]
    },
    {
      code: 'PRO',
      nom: 'Pro',
      prixMensuel: 5000,
      devise: 'FCFA',
      description: 'Toute la puissance de DubaGest sans aucune limite d\'utilisateurs ni de boutiques.',
      maxActivites: 3,
      maxPerimetres: 'Illimité',
      maxUtilisateursCommerce: 'Illimité',
      badge: 'Entreprise & Réseau',
      populaire: false,
      fonctionnalites: [
        'Les 3 activités réunies : Commerce + Services + Immobilier',
        'Boutiques, magasins et agences illimités',
        'Utilisateurs et collaborateurs illimités',
        'Gestion immobilière complète (biens, locataires, baux, loyers)',
        'Planning d\'interventions et chantiers multi-équipes',
        'Support prioritaire dédié 7j/7'
      ]
    }
  ]
};
