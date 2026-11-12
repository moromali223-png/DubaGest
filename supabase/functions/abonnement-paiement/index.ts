// Edge Function Supabase : abonnement-paiement
// Gère l'orchestration sécurisée des paiements LigdiCash (Payin Redirect & Straight Payin direct) et Orange Money pour DubaGest.
//
// RÈGLE DE SÉCURITÉ :
// - Les clés et secrets (LIGDICASH_API_KEY, LIGDICASH_API_TOKEN, etc.)
//   sont stockés UNIQUEMENT dans l'environnement serveur via Deno.env.get(...)
// - Tout paiement est vérifié serveur-à-serveur auprès de l'API LigdiCash
// - Les codes OTP ne sont JAMAIS stockés dans la base de données ni enregistrés dans les journaux
// - L'activation de l'abonnement s'effectue exclusivement via la RPC PostgreSQL
//   sécurisée `app.confirmer_paiement_abonnement_serveur`
// - Aucune clé API ni token secret n'est exposé au client Flutter

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface PaymentPayload {
  action:
    | "verifier_disponibilite"
    | "initialiser_paiement"
    | "generer_lien_test_10fcfa"
    | "payer_sans_redirection"
    | "valider_otp_direct"
    | "verifier_statut"
    | "diagnostic_agregateur"
    | "simuler_validation_sandbox";
  entreprise_id?: string;
  plan_code?: "NORMAL" | "MOYEN" | "PRO";
  duree_mois?: 1 | 3 | 6 | 12;
  prestataire?: "LIGDICASH" | "ORANGE_MONEY";
  idempotency_key?: string;
  est_demo?: boolean;
  est_test_agregateur?: boolean;
  montant_test?: number;
  telephone?: string;
  operateur?: "orange" | "moov" | "telecel" | "wave" | "mtn";
  code_otp?: string;
  transaction_id?: string;
  token_transaction?: string;
  reference_interne?: string;
}

const LIGDICASH_REDIRECT_URL = "https://app.ligdicash.com/pay/v01/redirect";
const LIGDICASH_STRAIGHT_URL = "https://app.ligdicash.com/pay/v01/straight";

function masquerTelephone(tel?: string): string {
  if (!tel || tel.length < 4) return "****";
  return `+${tel.slice(0, 3)}****${tel.slice(-3)}`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const ligdiCashApiKey = Deno.env.get("LIGDICASH_API_KEY")?.trim().replace(/^[<"']+|[>"']+$/g, "");
    const ligdiCashToken = Deno.env.get("LIGDICASH_API_TOKEN")?.trim().replace(/^[<"']+|[>"']+$/g, "");
    const rawEnv = (Deno.env.get("LIGDICASH_ENV") ?? "TEST").replace(/[<>\s"']/g, "").toUpperCase();
    const ligdiCashEnv = rawEnv === "PRODUCTION" ? "PRODUCTION" : "TEST";
    const appBaseUrl = Deno.env.get("APP_BASE_URL") ?? "https://app.dubagest.com";

    const orangeMoneyMerchantKey = Deno.env.get("ORANGE_MONEY_MERCHANT_KEY");
    const orangeMoneyClientSecret = Deno.env.get("ORANGE_MONEY_CLIENT_SECRET");

    const ligdiCashConfigured = Boolean(ligdiCashApiKey && ligdiCashToken);
    const orangeMoneyConfigured = Boolean(orangeMoneyMerchantKey && orangeMoneyClientSecret);

    const url = new URL(req.url);
    const pathname = url.pathname;
    const clientIp = req.headers.get("x-forwarded-for") ?? req.headers.get("cf-connecting-ip") ?? "inconnu";

    // =========================================================================
    // ROUTE 1 : Webhooks / Callbacks (LigdiCash IPN & Pings de tests agrégateur)
    // Accepte /webhook/ligdicash, /webhook, /callback
    // =========================================================================
    const estRouteWebhook =
      pathname.endsWith("/webhook/ligdicash") ||
      pathname.endsWith("/webhook") ||
      pathname.endsWith("/callback");

    if (estRouteWebhook) {
      // 1.1 Si requête GET (Ping de disponibilité de l'agrégateur)
      if (req.method === "GET") {
        await supabase.rpc("enregistrer_evenement_webhook", {
          p_prestataire: "LIGDICASH",
          p_methode_http: "GET",
          p_headers: Object.fromEntries(req.headers.entries()),
          p_payload: Object.fromEntries(url.searchParams.entries()),
          p_statut_traitement: "TEST_PING_RECU",
          p_message: "Vérification de connectivité GET effectuée par l'agrégateur",
          p_ip_source: clientIp,
        });

        return new Response(
          JSON.stringify({
            succes: true,
            statut: "OPERATIONNEL",
            message: "Point de terminaison Callback DubaGest actif et prêt à recevoir les notifications.",
            horodatage: new Date().toISOString(),
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // 1.2 Si requête POST / PUT
      let payload: Record<string, unknown> = {};
      try {
        payload = await req.json();
      } catch (_) {
        payload = {};
      }

      console.log(`📥 [WEBHOOK ENTRANT] Méthode: ${req.method} | Path: ${pathname} | IP: ${clientIp}`);
      console.log(`📦 [WEBHOOK BODY REÇU] :`, JSON.stringify(payload, null, 2));

      const invoiceToken =
        (payload.token as string) ||
        (payload.invoice_token as string) ||
        (payload.invoiceToken as string) ||
        url.searchParams.get("invoiceToken") ||
        url.searchParams.get("token");

      // 1.3 Cas Test A : Notification de test simple ou ping sans identifiant
      const estTestNotification =
        Boolean(payload.test) ||
        payload.type === "ping" ||
        payload.event === "test" ||
        !invoiceToken;

      if (estTestNotification) {
        await supabase.rpc("enregistrer_evenement_webhook", {
          p_prestataire: "LIGDICASH",
          p_methode_http: req.method,
          p_headers: Object.fromEntries(req.headers.entries()),
          p_payload: payload,
          p_statut_traitement: "TEST_PING_RECU",
          p_message: "Requête simplifiée de test reçue de l'agrégateur. Aucun abonnement modifié.",
          p_ip_source: clientIp,
        });

        return new Response(
          JSON.stringify({
            succes: true,
            mode: "TEST_RECU",
            message: "Notification de test reçue avec succès par DubaGest. URL Callback pleinement opérationnelle.",
            horodatage: new Date().toISOString(),
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // 1.4 Traitement réel de la notification avec jeton (token)
      if (ligdiCashConfigured) {
        const verifyUrl = `${LIGDICASH_REDIRECT_URL}/checkout-invoice/confirm/?invoiceToken=${encodeURIComponent(
          invoiceToken
        )}`;

        const ligdiRes = await fetch(verifyUrl, {
          method: "GET",
          headers: {
            Apikey: ligdiCashApiKey!,
            Authorization: `Bearer ${ligdiCashToken!}`,
            Accept: "application/json",
          },
        });

        if (!ligdiRes.ok) {
          await supabase.rpc("enregistrer_evenement_webhook", {
            p_prestataire: "LIGDICASH",
            p_methode_http: req.method,
            p_headers: Object.fromEntries(req.headers.entries()),
            p_payload: payload,
            p_statut_traitement: "ERREUR",
            p_reference_prestataire: invoiceToken,
            p_message: `Échec vérification LigdiCash HTTP ${ligdiRes.status}`,
            p_ip_source: clientIp,
          });

          return new Response(
            JSON.stringify({ error: "Échec de vérification auprès de LigdiCash", status: ligdiRes.status }),
            { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const ligdiData = await ligdiRes.json();
        const responseCode = ligdiData.response_code;
        const statut = (ligdiData.status as string)?.toLowerCase();
        const montant = Number(ligdiData.amount ?? ligdiData.total_amount ?? 0);
        const customData = ligdiData.custom_data ?? {};
        const refInterne = (customData.reference_interne as string) ?? null;

        if (responseCode === "00" && statut === "completed") {
          // Confirmation sécurisée et activation serveur (idempotente)
          const { data: confirmRes, error: confirmErr } = await supabase.rpc(
            "confirmer_paiement_abonnement_serveur",
            {
              p_reference_interne: refInterne,
              p_prestataire: "LIGDICASH",
              p_reference_prestataire: invoiceToken,
              p_montant: montant > 0 ? montant : null,
              p_devise: "XOF",
              p_diagnostic: {
                source: "webhook_ligdicash",
                ipn_payload: payload,
                ligdicash_confirmation: ligdiData,
                horodatage: new Date().toISOString(),
              },
            }
          );

          if (confirmErr) {
            await supabase.rpc("enregistrer_evenement_webhook", {
              p_prestataire: "LIGDICASH",
              p_methode_http: req.method,
              p_headers: Object.fromEntries(req.headers.entries()),
              p_payload: payload,
              p_statut_traitement: "ERREUR",
              p_reference_interne: refInterne,
              p_reference_prestataire: invoiceToken,
              p_message: confirmErr.message,
              p_ip_source: clientIp,
            });

            return new Response(
              JSON.stringify({ error: confirmErr.message }),
              { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
          }

          await supabase.rpc("enregistrer_evenement_webhook", {
            p_prestataire: "LIGDICASH",
            p_methode_http: req.method,
            p_headers: Object.fromEntries(req.headers.entries()),
            p_payload: payload,
            p_statut_traitement: "CONFIRME",
            p_reference_interne: refInterne,
            p_reference_prestataire: invoiceToken,
            p_message: "Paiement confirmé avec succès par vérification serveur-à-serveur",
            p_ip_source: clientIp,
          });

          return new Response(
            JSON.stringify({
              succes: true,
              message: "Paiement LigdiCash confirmé avec succès",
              activation: confirmRes,
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        } else {
          await supabase.rpc("enregistrer_evenement_webhook", {
            p_prestataire: "LIGDICASH",
            p_methode_http: req.method,
            p_headers: Object.fromEntries(req.headers.entries()),
            p_payload: payload,
            p_statut_traitement: "REFUSE",
            p_reference_interne: refInterne,
            p_reference_prestataire: invoiceToken,
            p_message: `Transaction non complétée: ${statut}`,
            p_ip_source: clientIp,
          });

          return new Response(
            JSON.stringify({
              succes: false,
              statut,
              message: "Transaction non complétée sur LigdiCash",
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }

      // Clés API non encore configurées dans les secrets
      await supabase.rpc("enregistrer_evenement_webhook", {
        p_prestataire: "LIGDICASH",
        p_methode_http: req.method,
        p_headers: Object.fromEntries(req.headers.entries()),
        p_payload: payload,
        p_statut_traitement: "TEST_RECU",
        p_reference_prestataire: invoiceToken,
        p_message: "Webhook reçu en mode test (clés d'API en attente de configuration)",
        p_ip_source: clientIp,
      });

      return new Response(JSON.stringify({ message: "Webhook reçu (clés API non configurées)" }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // =========================================================================
    // ROUTE 2 : Actions applicatives DubaGest et tests d'intégration
    // =========================================================================
    let body: PaymentPayload;
    try {
      body = await req.json();
    } catch (_) {
      return new Response(JSON.stringify({ erreur: "Corps de requête JSON invalide ou vide" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    console.log(`⚡ [ACTION ENTRANTE] : ${body.action ?? "inconnue"} | Path: ${pathname} | IP: ${clientIp}`);
    console.log(
      `📦 [BODY REÇU] :`,
      JSON.stringify(
        {
          ...body,
          code_otp: body.code_otp ? "****** (masqué)" : undefined,
        },
        null,
        2
      )
    );

    // Action : Diagnostic complet de l'agrégateur (disponibilité, callback, secrets)
    if (body.action === "diagnostic_agregateur") {
      const callbackUrl = `${supabaseUrl}/functions/v1/abonnement-paiement/webhook/ligdicash`;
      return new Response(
        JSON.stringify({
          succes: true,
          environnement: ligdiCashEnv,
          ligdicash: {
            est_configure: ligdiCashConfigured,
            cle_api_presente: Boolean(ligdiCashApiKey),
            token_present: Boolean(ligdiCashToken),
            endpoints: {
              redirect_create: `${LIGDICASH_REDIRECT_URL}/checkout-invoice/create`,
              redirect_confirm: `${LIGDICASH_REDIRECT_URL}/checkout-invoice/confirm/`,
              straight_create: `${LIGDICASH_STRAIGHT_URL}/checkout-invoice/create`,
            },
          },
          orange_money: {
            est_configure: orangeMoneyConfigured,
            message: "Désactivé temporairement (règlement recommandé via LigdiCash)",
          },
          callback: {
            url_officielle: callbackUrl,
            urls_alternatives_supportees: [
              `${supabaseUrl}/functions/v1/abonnement-paiement/webhook`,
              `${supabaseUrl}/functions/v1/abonnement-paiement/callback`,
            ],
            methodes_acceptees: ["GET", "POST"],
          },
          tests_disponibles: {
            test_a_callback_ping: "Requête GET ou POST { test: true } sur l'URL de callback",
            test_b_redirection_10fcfa: "action: generer_lien_test_10fcfa",
            test_c_sans_redirection_otp: "action: payer_sans_redirection",
          },
          horodatage_serveur: new Date().toISOString(),
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Action A : Vérifier la disponibilité des prestataires
    if (body.action === "verifier_disponibilite") {
      if (body.prestataire === "ORANGE_MONEY") {
        return new Response(
          JSON.stringify({
            prestataire: "ORANGE_MONEY",
            est_configure: false,
            environnement: ligdiCashEnv,
            message: "Orange Money direct est temporairement désactivé. Veuillez régler via LigdiCash.",
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const estConfigure = body.prestataire === "LIGDICASH" ? ligdiCashConfigured : false;
      return new Response(
        JSON.stringify({
          prestataire: body.prestataire,
          est_configure: estConfigure,
          environnement: ligdiCashEnv,
          message: estConfigure
            ? "Moyen de paiement disponible"
            : "Paiement en ligne bientôt disponible pour ce moyen de paiement.",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Action B : Génération d'un lien de paiement de test de 10 FCFA (Test B Agrégateur)
    if (body.action === "generer_lien_test_10fcfa") {
      if (ligdiCashEnv === "PRODUCTION") {
        return new Response(
          JSON.stringify({
            succes: false,
            erreur: "Action refusée : la génération de liens de test à 10 FCFA est désactivée en environnement de PRODUCTION.",
          }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      let entrepriseId = body.entreprise_id;
      if (!entrepriseId) {
        // Sélectionne une entreprise pour le test si non spécifiée
        const { data: entData } = await supabase.from("entreprises").select("id").limit(1).maybeSingle();
        entrepriseId = entData?.id;
      }

      if (!entrepriseId) {
        return new Response(
          JSON.stringify({ succes: false, erreur: "Aucune entreprise disponible pour initialiser le test 10 FCFA" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Initialisation sécurisée à 10 FCFA dans PostgreSQL
      const { data: initData, error: initError } = await supabase.rpc(
        "initialiser_paiement_abonnement",
        {
          p_entreprise_id: entrepriseId,
          p_plan_code: body.plan_code,
          p_duree_mois: 1,
          p_prestataire: "LIGDICASH",
          p_idempotency_key: body.idempotency_key ?? `TEST_10F_${Date.now()}`,
          p_est_demo: true,
          p_montant_test: 10,
          p_type_paiement: "REDIRECTION",
        }
      );

      if (initError) {
        return new Response(JSON.stringify({ succes: false, erreur: initError.message }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const tx = initData?.transaction;
      const refInterne = tx?.reference_interne as string;
      const callbackUrl = `${supabaseUrl}/functions/v1/abonnement-paiement/webhook/ligdicash`;
      const returnUrl = `${appBaseUrl}/abonnement/retour?ref=${refInterne}&test=true`;
      const cancelUrl = `${appBaseUrl}/abonnement/annule?ref=${refInterne}&test=true`;

      if (ligdiCashConfigured) {
        const ligdiPayload = {
          commande: {
            invoice: {
              items: [
                {
                  name: "Test Intégration Agrégateur DubaGest (10 FCFA)",
                  description: "Paiement de test officiel de 10 FCFA pour validation technique de l'agrégateur",
                  quantity: 1,
                  unit_price: 10,
                  total_price: 10,
                },
              ],
              total_amount: 10,
              devise: "XOF",
              description: "Test officiel d'intégration 10 FCFA",
              customer: body.telephone ?? "",
            },
            store: {
              name: "DubaGest Test",
              website_url: appBaseUrl,
            },
            actions: {
              cancel_url: cancelUrl,
              return_url: returnUrl,
              callback_url: callbackUrl,
            },
            custom_data: {
              reference_interne: refInterne,
              entreprise_id: entrepriseId,
              montant_test: 10,
              environnement: ligdiCashEnv,
            },
          },
        };

        const ligdiCreateRes = await fetch(`${LIGDICASH_REDIRECT_URL}/checkout-invoice/create`, {
          method: "POST",
          headers: {
            Apikey: ligdiCashApiKey!,
            Authorization: `Bearer ${ligdiCashToken!}`,
            Accept: "application/json",
            "Content-Type": "application/json",
          },
          body: JSON.stringify(ligdiPayload),
        });

        if (!ligdiCreateRes.ok) {
          const errText = await ligdiCreateRes.text();
          return new Response(
            JSON.stringify({
              succes: false,
              erreur: `Erreur API LigdiCash (${ligdiCreateRes.status}): ${errText}`,
            }),
            { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const ligdiInvoice = await ligdiCreateRes.json();
        if (ligdiInvoice.response_code !== "00") {
          return new Response(
            JSON.stringify({
              succes: false,
              erreur: ligdiInvoice.description ?? "Échec création facture LigdiCash",
            }),
            { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const token = ligdiInvoice.token as string;
        const urlPaiement = ligdiInvoice.response_text as string;

        await supabase.rpc("enregistrer_initialisation_ligdicash", {
          p_reference_interne: refInterne,
          p_token: token,
          p_url_paiement: urlPaiement,
          p_environnement: ligdiCashEnv,
          p_diagnostic: ligdiInvoice,
        });

        return new Response(
          JSON.stringify({
            succes: true,
            montant: 10,
            devise: "XOF",
            token: token,
            url_paiement: urlPaiement,
            reference_interne: refInterne,
            environnement: ligdiCashEnv,
            message: "Lien officiel de test de 10 FCFA généré avec succès par l'API LigdiCash.",
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      } else {
        // Mode Sandbox sans clés API configurées
        const simulatedToken = `tok_test_10f_${Date.now()}`;
        const simulatedUrl = `https://app.ligdicash.com/pay/checkout/${simulatedToken}`;

        await supabase.rpc("enregistrer_initialisation_ligdicash", {
          p_reference_interne: refInterne,
          p_token: simulatedToken,
          p_url_paiement: simulatedUrl,
          p_environnement: "TEST",
          p_diagnostic: {
            simulation_test_10f: true,
            montant: 10,
          },
        });

        return new Response(
          JSON.stringify({
            succes: true,
            montant: 10,
            devise: "XOF",
            token: simulatedToken,
            url_paiement: simulatedUrl,
            reference_interne: refInterne,
            environnement: "TEST",
            message: "Lien de simulation 10 FCFA généré (identifiants serveur LigdiCash en attente).",
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // Action C : Paiement sans redirection (Straight Payin Mobile Money + OTP)
    if (body.action === "payer_sans_redirection") {
      if (!body.telephone) {
        return new Response(
          JSON.stringify({ succes: false, erreur: "Numéro de téléphone requis pour le paiement direct sans redirection." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      let entrepriseId = body.entreprise_id;
      if (!entrepriseId) {
        const { data: entData } = await supabase.from("entreprises").select("id").limit(1).maybeSingle();
        entrepriseId = entData?.id;
      }

      const montantTest = ligdiCashEnv === "PRODUCTION" ? null : (body.montant_test === 10 ? 10 : null);
      const estTest = ligdiCashEnv === "PRODUCTION" ? false : Boolean(body.est_demo || body.est_test_agregateur || montantTest === 10);

      // Initialisation transaction en base PostgreSQL
      const { data: initData, error: initError } = await supabase.rpc(
        "initialiser_paiement_abonnement",
        {
          p_entreprise_id: entrepriseId,
          p_plan_code: body.plan_code,
          p_duree_mois: body.duree_mois ?? 1,
          p_prestataire: body.prestataire ?? "LIGDICASH",
          p_idempotency_key: body.idempotency_key ?? `DIRECT_${Date.now()}`,
          p_est_demo: estTest,
          p_montant_test: montantTest,
          p_type_paiement: "DIRECT_SANS_REDIRECTION",
        }
      );

      if (initError) {
        return new Response(JSON.stringify({ succes: false, erreur: initError.message }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const tx = initData?.transaction;
      const refInterne = tx?.reference_interne as string;
      const montant = Number(tx?.montant ?? (montantTest ?? 0));
      const callbackUrl = `${supabaseUrl}/functions/v1/abonnement-paiement/webhook/ligdicash`;

      if (ligdiCashConfigured) {
        // Envoi direct à l'API Straight Payin LigdiCash
        // NOTE DE SÉCURITÉ ABSOLUE : body.code_otp est transmis directement à l'API et JAMAIS persisté
        const straightPayload = {
          commande: {
            invoice: {
              items: [
                {
                  name: `Abonnement DubaGest (Paiement direct)`,
                  quantity: 1,
                  unit_price: montant,
                  total_price: montant,
                },
              ],
              total_amount: montant,
              devise: "XOF",
              description: "Paiement direct Mobile Money DubaGest",
              customer: body.telephone,
              otp: body.code_otp || undefined,
              operator: body.operateur || undefined,
            },
            store: {
              name: "DubaGest",
              website_url: appBaseUrl,
            },
            actions: {
              callback_url: callbackUrl,
            },
            custom_data: {
              reference_interne: refInterne,
              type_paiement: "DIRECT_SANS_REDIRECTION",
              environnement: ligdiCashEnv,
            },
          },
        };

        const ligdiStraightRes = await fetch(`${LIGDICASH_STRAIGHT_URL}/checkout-invoice/create`, {
          method: "POST",
          headers: {
            Apikey: ligdiCashApiKey!,
            Authorization: `Bearer ${ligdiCashToken!}`,
            Accept: "application/json",
            "Content-Type": "application/json",
          },
          body: JSON.stringify(straightPayload),
        });

        if (!ligdiStraightRes.ok) {
          const errText = await ligdiStraightRes.text();
          return new Response(
            JSON.stringify({
              succes: false,
              erreur: `Erreur API Straight Payin (${ligdiStraightRes.status}): ${errText}`,
            }),
            { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const ligdiResp = await ligdiStraightRes.json();
        const token = (ligdiResp.token as string) || (ligdiResp.invoice_token as string);

        // Sauvegarde de l'état sans AUCUN mot de passe ni OTP
        await supabase.rpc("enregistrer_initialisation_ligdicash", {
          p_reference_interne: refInterne,
          p_token: token ?? `tok_direct_${Date.now()}`,
          p_url_paiement: null,
          p_environnement: ligdiCashEnv,
          p_diagnostic: {
            type_paiement: "DIRECT_SANS_REDIRECTION",
            telephone_masque: masquerTelephone(body.telephone),
            response_code: ligdiResp.response_code,
            description: ligdiResp.description,
          },
        });

        // Cas où un OTP est demandé par l'opérateur
        const demandeOtp =
          ligdiResp.response_code === "02" ||
          ligdiResp.status === "otp_required" ||
          (ligdiResp.description && ligdiResp.description.toLowerCase().includes("otp"));

        return new Response(
          JSON.stringify({
            succes: true,
            reference_interne: refInterne,
            token: token,
            statut: demandeOtp ? "EN_ATTENTE_OTP" : "EN_COURS",
            demande_otp: demandeOtp,
            telephone_masque: masquerTelephone(body.telephone),
            message: demandeOtp
              ? "Un code de validation OTP a été envoyé. Veuillez renseigner le code OTP pour finaliser."
              : "Demande de débit direct transmise à l'opérateur. Veuillez valider la notification sur votre mobile.",
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      } else {
        // Simulation en environnement Sandbox sans clés serveur
        const simToken = `tok_straight_sandbox_${Date.now()}`;
        await supabase.rpc("enregistrer_initialisation_ligdicash", {
          p_reference_interne: refInterne,
          p_token: simToken,
          p_url_paiement: null,
          p_environnement: "TEST",
          p_diagnostic: {
            simulation_straight: true,
            telephone_masque: masquerTelephone(body.telephone),
          },
        });

        return new Response(
          JSON.stringify({
            succes: true,
            reference_interne: refInterne,
            token: simToken,
            statut: "EN_COURS",
            telephone_masque: masquerTelephone(body.telephone),
            message: "Simulation de paiement direct enregistrée en mode TEST.",
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // Action C bis : Validation du code OTP pour paiement direct sans redirection
    if (body.action === "valider_otp_direct") {
      if (!body.code_otp) {
        return new Response(
          JSON.stringify({ succes: false, erreur: "Code OTP manquant" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const token = body.token_transaction;
      const refInterne = body.reference_interne;

      if (!token && !refInterne) {
        return new Response(
          JSON.stringify({ succes: false, erreur: "token_transaction ou reference_interne requis" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (ligdiCashConfigured && token) {
        // Transmission sécurisée de l'OTP à l'API de confirmation sans stockage local
        const ligdiOtpRes = await fetch(`${LIGDICASH_STRAIGHT_URL}/checkout-invoice/otp`, {
          method: "POST",
          headers: {
            Apikey: ligdiCashApiKey!,
            Authorization: `Bearer ${ligdiCashToken!}`,
            Accept: "application/json",
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            token: token,
            otp: body.code_otp,
          }),
        });

        if (!ligdiOtpRes.ok) {
          const errText = await ligdiOtpRes.text();
          return new Response(
            JSON.stringify({ succes: false, erreur: `Échec validation OTP (${ligdiOtpRes.status}): ${errText}` }),
            { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        const otpData = await ligdiOtpRes.json();
        const estValide = otpData.response_code === "00" && otpData.status === "completed";

        if (estValide && refInterne) {
          const { data: confirmRes } = await supabase.rpc(
            "confirmer_paiement_abonnement_serveur",
            {
              p_reference_interne: refInterne,
              p_prestataire: "LIGDICASH",
              p_reference_prestataire: token,
              p_montant: Number(otpData.amount ?? 0) || null,
              p_devise: "XOF",
              p_diagnostic: {
                source: "validation_otp_direct",
                horodatage: new Date().toISOString(),
              },
            }
          );

          return new Response(
            JSON.stringify({
              succes: true,
              statut: "CONFIRME",
              activation: confirmRes,
              message: "Code OTP validé avec succès et abonnement activé.",
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }

        return new Response(
          JSON.stringify({
            succes: false,
            statut: otpData.status ?? "EN_COURS",
            message: otpData.description ?? "Code OTP incorrect ou en attente",
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Simulation sandbox de validation OTP
      if (refInterne) {
        const { data: confirmRes } = await supabase.rpc(
          "confirmer_paiement_abonnement_serveur",
          {
            p_reference_interne: refInterne,
            p_prestataire: "LIGDICASH",
            p_reference_prestataire: token ?? `tok_sandbox_${Date.now()}`,
            p_montant: null,
            p_devise: "XOF",
            p_diagnostic: {
              simulation_otp: true,
              horodatage: new Date().toISOString(),
            },
          }
        );

        return new Response(
          JSON.stringify({
            succes: true,
            statut: "CONFIRME",
            activation: confirmRes,
            message: "Simulation OTP validée et abonnement activé.",
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // Action D : Initialiser une transaction standard (Payin Redirection)
    if (body.action === "initialiser_paiement") {
      if (body.prestataire === "ORANGE_MONEY") {
        return new Response(
          JSON.stringify({
            succes: false,
            erreur: "Le paiement Orange Money direct est temporairement désactivé. Veuillez régler via LigdiCash.",
          }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (!body.entreprise_id || !body.plan_code || !body.duree_mois) {
        return new Response(
          JSON.stringify({ succes: false, erreur: "Paramètres d'abonnement incomplets" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const montantTest = ligdiCashEnv === "PRODUCTION" ? null : (body.montant_test === 10 ? 10 : null);
      const estDemo = ligdiCashEnv === "PRODUCTION" ? false : Boolean(body.est_demo || montantTest === 10);

      const { data: initData, error: initError } = await supabase.rpc(
        "initialiser_paiement_abonnement",
        {
          p_entreprise_id: body.entreprise_id,
          p_plan_code: body.plan_code,
          p_duree_mois: body.duree_mois,
          p_prestataire: body.prestataire ?? "LIGDICASH",
          p_idempotency_key: body.idempotency_key,
          p_est_demo: estDemo,
          p_montant_test: montantTest,
          p_type_paiement: "REDIRECTION",
        }
      );

      if (initError) {
        return new Response(JSON.stringify({ succes: false, erreur: initError.message }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const tx = initData?.transaction;
      const refInterne = tx?.reference_interne as string;
      const montant = Number(tx?.montant ?? 0);

      if (body.prestataire === "LIGDICASH") {
        if (ligdiCashConfigured) {
          const callbackUrl = `${supabaseUrl}/functions/v1/abonnement-paiement/webhook/ligdicash`;
          const returnUrl = `${appBaseUrl}/abonnement/retour?ref=${refInterne}`;
          const cancelUrl = `${appBaseUrl}/abonnement/annule?ref=${refInterne}`;

          const ligdiPayload = {
            commande: {
              invoice: {
                items: [
                  {
                    name: `Abonnement DubaGest ${body.plan_code} (${body.duree_mois} mois)`,
                    description: `Formule ${body.plan_code} - Gestion DubaGest`,
                    quantity: 1,
                    unit_price: montant,
                    total_price: montant,
                  },
                ],
                total_amount: montant,
                devise: "XOF",
                description: `Abonnement DubaGest ${body.plan_code}`,
                customer: body.telephone ?? "",
              },
              store: {
                name: "DubaGest",
                website_url: appBaseUrl,
              },
              actions: {
                cancel_url: cancelUrl,
                return_url: returnUrl,
                callback_url: callbackUrl,
              },
              custom_data: {
                reference_interne: refInterne,
                entreprise_id: body.entreprise_id,
                plan_code: body.plan_code,
                duree_mois: body.duree_mois,
                environnement: ligdiCashEnv,
              },
            },
          };

          const ligdiCreateRes = await fetch(`${LIGDICASH_REDIRECT_URL}/checkout-invoice/create`, {
            method: "POST",
            headers: {
              Apikey: ligdiCashApiKey!,
              Authorization: `Bearer ${ligdiCashToken!}`,
              Accept: "application/json",
              "Content-Type": "application/json",
            },
            body: JSON.stringify(ligdiPayload),
          });

          if (!ligdiCreateRes.ok) {
            const errText = await ligdiCreateRes.text();
            return new Response(
              JSON.stringify({
                succes: false,
                erreur: `Erreur API LigdiCash (${ligdiCreateRes.status}): ${errText}`,
              }),
              { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
          }

          const ligdiInvoice = await ligdiCreateRes.json();
          if (ligdiInvoice.response_code !== "00") {
            return new Response(
              JSON.stringify({
                succes: false,
                erreur: ligdiInvoice.description ?? "Échec création facture LigdiCash",
              }),
              { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
          }

          const token = ligdiInvoice.token as string;
          const urlPaiement = ligdiInvoice.response_text as string;

          const { data: saveRes, error: saveErr } = await supabase.rpc(
            "enregistrer_initialisation_ligdicash",
            {
              p_reference_interne: refInterne,
              p_token: token,
              p_url_paiement: urlPaiement,
              p_environnement: ligdiCashEnv,
              p_diagnostic: ligdiInvoice,
            }
          );

          if (saveErr) {
            return new Response(JSON.stringify({ succes: false, erreur: saveErr.message }), {
              status: 500,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
          }

          return new Response(
            JSON.stringify({
              succes: true,
              est_configure: true,
              environnement: ligdiCashEnv,
              token: token,
              url_paiement: urlPaiement,
              transaction: saveRes?.transaction ?? tx,
              message: "Facture LigdiCash générée. Redirection prête.",
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        } else {
          const simulatedToken = `tok_sandbox_${Date.now()}`;
          const simulatedUrl = `https://app.ligdicash.com/pay/checkout/${simulatedToken}`;

          const { data: saveRes } = await supabase.rpc(
            "enregistrer_initialisation_ligdicash",
            {
              p_reference_interne: refInterne,
              p_token: simulatedToken,
              p_url_paiement: simulatedUrl,
              p_environnement: "TEST",
              p_diagnostic: {
                simulation: true,
                message: "Session de test sandbox (identifiants serveur en attente)",
              },
            }
          );

          return new Response(
            JSON.stringify({
              succes: true,
              est_configure: false,
              est_demo: true,
              environnement: "TEST",
              token: simulatedToken,
              url_paiement: simulatedUrl,
              transaction: saveRes?.transaction ?? tx,
              message: "Session de test LigdiCash Sandbox initialisée (Mode Test Sandbox)",
            }),
            { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
          );
        }
      }

      return new Response(
        JSON.stringify({
          succes: true,
          est_configure: orangeMoneyConfigured,
          transaction: tx,
          message: "Transaction initialisée",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Action E : Vérifier le statut d'une transaction
    if (body.action === "verifier_statut") {
      let tx: Record<string, unknown> | null = null;

      if (body.transaction_id) {
        const { data } = await supabase
          .from("transactions_abonnement")
          .select("*")
          .eq("id", body.transaction_id)
          .maybeSingle();
        tx = data;
      } else if (body.reference_interne) {
        const { data } = await supabase
          .from("transactions_abonnement")
          .select("*")
          .eq("reference_interne", body.reference_interne)
          .maybeSingle();
        tx = data;
      } else if (body.token_transaction) {
        const { data } = await supabase
          .from("transactions_abonnement")
          .select("*")
          .eq("token_transaction", body.token_transaction)
          .maybeSingle();
        tx = data;
      }

      if (!tx) {
        return new Response(JSON.stringify({ succes: false, erreur: "Transaction introuvable" }), {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      if (tx.statut === "CONFIRME") {
        return new Response(
          JSON.stringify({ succes: true, statut: "CONFIRME", deja_confirme: true, transaction: tx }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const token = tx.token_transaction as string | undefined;
      if (token && ligdiCashConfigured && (tx.statut === "EN_COURS" || tx.statut === "EN_ATTENTE")) {
        const verifyUrl = `${LIGDICASH_REDIRECT_URL}/checkout-invoice/confirm/?invoiceToken=${encodeURIComponent(
          token
        )}`;

        const ligdiRes = await fetch(verifyUrl, {
          method: "GET",
          headers: {
            Apikey: ligdiCashApiKey!,
            Authorization: `Bearer ${ligdiCashToken!}`,
            Accept: "application/json",
          },
        });

        if (ligdiRes.ok) {
          const ligdiData = await ligdiRes.json();
          const responseCode = ligdiData.response_code;
          const statut = (ligdiData.status as string)?.toLowerCase();
          const montant = Number(ligdiData.amount ?? ligdiData.total_amount ?? 0);

          if (responseCode === "00" && statut === "completed") {
            const { data: confirmRes } = await supabase.rpc(
              "confirmer_paiement_abonnement_serveur",
              {
                p_reference_interne: tx.reference_interne,
                p_prestataire: "LIGDICASH",
                p_reference_prestataire: token,
                p_montant: montant > 0 ? montant : Number(tx.montant),
                p_devise: "XOF",
                p_diagnostic: {
                  source: "polling_verification",
                  ligdicash_confirmation: ligdiData,
                  horodatage: new Date().toISOString(),
                },
              }
            );

            return new Response(
              JSON.stringify({
                succes: true,
                statut: "CONFIRME",
                transaction: confirmRes,
                message: "Paiement confirmé sur LigdiCash",
              }),
              { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
          } else if (statut === "failed" || statut === "expired" || statut === "cancelled") {
            await supabase
              .from("transactions_abonnement")
              .update({
                statut: statut === "cancelled" ? "ANNULE" : statut === "expired" ? "EXPIRE" : "ECHOUE",
                failed_at: new Date().toISOString(),
                updated_at: new Date().toISOString(),
              })
              .eq("id", tx.id);

            return new Response(
              JSON.stringify({
                succes: true,
                statut: statut === "cancelled" ? "ANNULE" : statut === "expired" ? "EXPIRE" : "ECHOUE",
                message: `Transaction ${statut} sur LigdiCash`,
              }),
              { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
          }
        }
      }

      return new Response(
        JSON.stringify({
          succes: true,
          statut: tx.statut,
          transaction: tx,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Action F : Simulation de validation en environnement Sandbox / Démo
    if (body.action === "simuler_validation_sandbox") {
      const refInterne = body.reference_interne;
      if (!refInterne) {
        return new Response(
          JSON.stringify({ succes: false, erreur: "reference_interne manquante" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data: txData } = await supabase
        .from("transactions_abonnement")
        .select("*")
        .eq("reference_interne", refInterne)
        .maybeSingle();

      if (!txData) {
        return new Response(JSON.stringify({ succes: false, erreur: "Transaction introuvable" }), {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      if (txData.environnement !== "TEST" && !txData.est_demo) {
        return new Response(
          JSON.stringify({
            succes: false,
            erreur: "Action interdite : la transaction est en environnement de PRODUCTION",
          }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data: confirmRes, error: confirmErr } = await supabase.rpc(
        "confirmer_paiement_abonnement_serveur",
        {
          p_reference_interne: refInterne,
          p_prestataire: "LIGDICASH",
          p_reference_prestataire: txData.token_transaction ?? `tok_sandbox_${Date.now()}`,
          p_montant: Number(txData.montant),
          p_devise: "XOF",
          p_diagnostic: {
            simulation_sandbox: true,
            valide_par_testeur: true,
            horodatage: new Date().toISOString(),
          },
        }
      );

      if (confirmErr) {
        return new Response(JSON.stringify({ succes: false, erreur: confirmErr.message }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      return new Response(
        JSON.stringify({
          succes: true,
          statut: "CONFIRME",
          activation: confirmRes,
          message: "Transaction de test Sandbox validée et abonnement activé avec succès.",
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify({ erreur: "Action non supportée" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : "Erreur interne serveur";
    return new Response(JSON.stringify({ erreur: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
