import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const languages = ['en','zh-Hans','zh-Hant','ja','fr','de','es'];
const root = path.resolve(import.meta.dirname, '..');
for (const table of ['Localizable', 'Legal']) {
  const catalog = JSON.parse(fs.readFileSync(`${root}/AIWardrobe/${table}.xcstrings`));
  for (const [key, record] of Object.entries(catalog.strings)) {
    for (const lang of languages) {
      assert(record.localizations[lang]?.stringUnit.value.length, `${table}:${lang}:${key}`);
      assert.equal(record.localizations[lang].stringUnit.state, 'translated');
    }
  }
}
for (const lang of languages) {
  const info = fs.readFileSync(`${root}/AIWardrobe/Resources/${lang}.lproj/InfoPlist.strings`, 'utf8');
  assert(info.includes('CFBundleDisplayName'));
  assert(info.includes('NSCameraUsageDescription'));
  assert(info.includes('NSLocationWhenInUseUsageDescription'));
  assert(info.includes('NSMicrophoneUsageDescription'));
  assert(info.includes('NSSpeechRecognitionUsageDescription'));
}
const files = fs.readdirSync(`${root}/AIWardrobe`, {recursive:true}).filter(f=>fs.statSync(`${root}/AIWardrobe/${f}`).isFile());
assert(!files.some(f=>/PersonalCatalog|WornCatalog|default-front|real-|\.heic$/i.test(f)), 'Private assets present');
for (const region of ['cn','jp','us','gb','fr','de','es']) {
  assert(fs.existsSync(`${root}/AIWardrobe/Resources/PublicAssets.xcassets/models-${region}.imageset/models-${region}.png`));
}
for (const scene of ['office','weekend','outdoor']) {
  assert(fs.existsSync(`${root}/AIWardrobe/Resources/PublicAssets.xcassets/demo-${scene}.imageset/demo-${scene}.png`));
}
const project=fs.readFileSync(`${root}/AIWardrobe.xcodeproj/project.pbxproj`, 'utf8');
assert(project.includes('com.tinyworm.AIWardrobe.Public'));
assert(!project.includes('UIInterfaceOrientationLandscape'));
assert(project.includes('UIInterfaceOrientationPortrait'));
assert(!fs.readFileSync(`${root}/AIWardrobe/AIWardrobe.entitlements`,'utf8').includes('icloud'));
console.log('PASS: 7 complete locales, permission prompts, 14 fictional models, 3 demo outfits, no private assets, separate identity, portrait iPhone target');
for (const locale of ['en-US','zh-Hans','zh-Hant','ja','fr-FR','de-DE','es-ES']) {
  const metadata = JSON.parse(fs.readFileSync(`${root}/AppStore/Metadata/${locale}.json`));
  for (const [field, max] of [['name',30],['subtitle',30],['promotionalText',170],['description',4000],['keywords',100]]) {
    assert(metadata[field].length > 0 && metadata[field].length <= max, `${locale}:${field} limit`);
  }
  assert(metadata.privacyURL.startsWith('https://wliao78.github.io/AI-Wardrobe-Support/'));
}
for (const language of languages) {
  for (let tab = 0; tab < 4; tab++) {
    const png = fs.readFileSync(`${root}/AppStore/Screenshots/${language}/iphone-69-${tab}.png`);
    assert.equal(png.toString('hex', 0, 8), '89504e470d0a1a0a');
    assert.equal(png.readUInt32BE(16), 1320);
    assert.equal(png.readUInt32BE(20), 2868);
    assert(png.length > 180000, `${language}:${tab} suspiciously blank screenshot`);
  }
}
console.log('PASS: 7 store metadata sets within field limits and 28 full-resolution screenshot files');
