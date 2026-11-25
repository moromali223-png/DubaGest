const fs = require('fs');
const path = require('path');
const https = require('https');
const crypto = require('crypto');
const { execSync } = require('child_process');

function getGitHubToken() {
  const output = execSync('git credential fill', {
    input: 'protocol=https\nhost=github.com\n',
    encoding: 'utf-8'
  });
  const match = output.match(/password=(.+)/);
  if (!match) throw new Error('Could not find GitHub token');
  return match[1].trim();
}

function requestJson(options, postData = null) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          const parsed = body ? JSON.parse(body) : {};
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve({ statusCode: res.statusCode, data: parsed });
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${body}`));
          }
        } catch (e) {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve({ statusCode: res.statusCode, raw: body });
          } else {
            reject(new Error(`HTTP ${res.statusCode}: ${body}`));
          }
        }
      });
    });
    req.on('error', reject);
    if (postData) {
      req.write(typeof postData === 'string' ? postData : JSON.stringify(postData));
    }
    req.end();
  });
}

function uploadAsset(uploadUrlTemplate, filePath, assetName, token) {
  return new Promise((resolve, reject) => {
    // uploadUrlTemplate format: https://uploads.github.com/repos/owner/repo/releases/ID/assets{?name,label}
    const cleanUrl = uploadUrlTemplate.replace(/\{\?name,label\}$/, '');
    const url = new URL(cleanUrl);
    url.searchParams.set('name', assetName);

    const stats = fs.statSync(filePath);
    const fileStream = fs.createReadStream(filePath);

    const req = https.request({
      hostname: url.hostname,
      path: url.pathname + url.search,
      method: 'POST',
      headers: {
        'User-Agent': 'DubaGest-Release-Publisher',
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Length': stats.size,
        'Accept': 'application/vnd.github.v3+json'
      }
    }, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(parsed);
          } else {
            reject(new Error(`Upload HTTP ${res.statusCode}: ${body}`));
          }
        } catch (e) {
          reject(new Error(`Upload parse error: ${body}`));
        }
      });
    });

    req.on('error', reject);

    let uploaded = 0;
    fileStream.on('data', (chunk) => {
      uploaded += chunk.length;
      const pct = ((uploaded / stats.size) * 100).toFixed(1);
      process.stdout.write(`\rUploading ${assetName}: ${pct}% (${(uploaded / (1024 * 1024)).toFixed(1)} MB / ${(stats.size / (1024 * 1024)).toFixed(1)} MB)`);
    });

    fileStream.on('end', () => {
      process.stdout.write('\nUpload complete, waiting for GitHub response...\n');
    });

    fileStream.pipe(req);
  });
}

async function main() {
  const apkPath = path.resolve(__dirname, '../build/app/outputs/flutter-apk/app-release.apk');
  if (!fs.existsSync(apkPath)) {
    console.error('APK non trouvé:', apkPath);
    process.exit(1);
  }

  const fileBytes = fs.readFileSync(apkPath);
  const fileSize = fileBytes.length;
  const sha256Hash = crypto.createHash('sha256').update(fileBytes).digest('hex').toLowerCase();

  console.log('--- APK DETAILS ---');
  console.log('Path:', apkPath);
  console.log('Size:', fileSize, `bytes (~${(fileSize / (1024 * 1024)).toFixed(2)} MB)`);
  console.log('SHA-256:', sha256Hash);

  const token = getGitHubToken();
  const repo = 'moromali223-png/DubaGest';
  const tag = 'v1.0.4';
  const releaseName = 'DubaGest v1.0.4';

  // 1. Get or create release
  console.log('\nChecking existing releases...');
  const { data: releases } = await requestJson({
    hostname: 'api.github.com',
    path: `/repos/${repo}/releases`,
    method: 'GET',
    headers: {
      'User-Agent': 'DubaGest-Release-Publisher',
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/vnd.github.v3+json'
    }
  });

  let targetRelease = releases.find(r => r.tag_name === tag);

  if (!targetRelease) {
    console.log(`Creating release ${tag}...`);
    const { data: newRelease } = await requestJson({
      hostname: 'api.github.com',
      path: `/repos/${repo}/releases`,
      method: 'POST',
      headers: {
        'User-Agent': 'DubaGest-Release-Publisher',
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.github.v3+json'
      }
    }, {
      tag_name: tag,
      target_commitish: 'main',
      name: releaseName,
      body: 'Release officielle DubaGest Android v1.0.4 (versionCode 5)\n\n- Téléchargement APK officiel\n- Mises à jour in-app transparentes sans désinstallation\n- Vérification d\'intégrité SHA-256\n- Correctifs archivage produit, réactivité des boutons de confirmation\n- Enregistrement instantané des interventions & contrats de service\n- Traçabilité des lots et sélection de lot lors des ventes',
      draft: false,
      prerelease: false
    });
    targetRelease = newRelease;
    console.log(`Release created with ID: ${targetRelease.id}`);
  } else {
    console.log(`Release ${tag} already exists with ID: ${targetRelease.id}`);
  }

  // 2. Check if asset already exists in release
  const assetName = 'DubaGest-Android.apk';
  const existingAsset = targetRelease.assets ? targetRelease.assets.find(a => a.name === assetName) : null;
  if (existingAsset) {
    console.log(`Asset ${assetName} already exists with ID ${existingAsset.id}, deleting old asset first...`);
    await requestJson({
      hostname: 'api.github.com',
      path: `/repos/${repo}/releases/assets/${existingAsset.id}`,
      method: 'DELETE',
      headers: {
        'User-Agent': 'DubaGest-Release-Publisher',
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/vnd.github.v3+json'
      }
    });
    console.log('Old asset deleted.');
  }

  // 3. Upload APK asset
  console.log(`Uploading ${assetName} to release ${tag}...`);
  const uploadedAsset = await uploadAsset(targetRelease.upload_url, apkPath, assetName, token);
  console.log('\nAsset successfully uploaded!');
  console.log('Download URL:', uploadedAsset.browser_download_url);

  // 4. Update vitrine/_redirects
  const redirectsPath = path.resolve(__dirname, '../vitrine/_redirects');
  let redirectsContent = fs.readFileSync(redirectsPath, 'utf-8');
  redirectsContent = redirectsContent.replace(
    /https:\/\/github\.com\/moromali223-png\/DubaGest\/releases\/download\/[^\/]+\/DubaGest-Android\.apk/g,
    `https://github.com/moromali223-png/DubaGest/releases/download/${tag}/DubaGest-Android.apk`
  );
  fs.writeFileSync(redirectsPath, redirectsContent, 'utf-8');
  console.log('\nUpdated vitrine/_redirects with new release URL');

  // 5. Update vitrine/version.json and web/version.json
  const nowIso = new Date().toISOString();
  const updateManifest = (filePath) => {
    if (!fs.existsSync(filePath)) return;
    const manifest = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
    manifest.updated_at = nowIso;
    manifest.android = {
      latest_version: '1.0.4',
      version_code: 5,
      minimum_supported_version: '1.0.0',
      minimum_supported_code: 1,
      apk_url: 'https://dubagest.com/downloads/DubaGest-Android.apk',
      sha256: sha256Hash,
      file_size: fileSize,
      force_update: false,
      release_date: nowIso.split('T')[0],
      release_notes: [
        'Mise à jour Android officielle DubaGest v1.0.4',
        'Correction réactivité des dialogues et de l\'archivage',
        'Sélection et affichage des lots de stock',
        'Enregistrement ultra-rapide des interventions et contrats de service',
        'Vérification cryptographique intégrale SHA-256'
      ]
    };
    manifest.pwa = {
      latest_version: '1.0.4',
      minimum_supported_version: '1.0.0',
      force_update: false,
      release_date: nowIso.split('T')[0],
      release_notes: [
        'Mise à jour PWA officielle DubaGest v1.0.4',
        'Correction réactivité des dialogues et de l\'archivage',
        'Sélection et affichage des lots de stock',
        'Enregistrement ultra-rapide des interventions et contrats de service',
        'Téléversement photos en tâche de fond fluide'
      ]
    };
    fs.writeFileSync(filePath, JSON.stringify(manifest, null, 4), 'utf-8');
    console.log('Updated', filePath);
  };

  updateManifest(path.resolve(__dirname, '../vitrine/version.json'));
  updateManifest(path.resolve(__dirname, '../web/version.json'));

  console.log('\n--- ALL UPDATES APPLIED SUCCESSFULLY ---');
}

main().catch(err => {
  console.error('\nERROR:', err);
  process.exit(1);
});
