// Builds the SideStore/AltStore source (apps.json) from the GitHub releases.
// Usage: gh api repos/OWNER/REPO/releases | node scripts/make-source.mjs OWNER/REPO https://OWNER.github.io/REPO
import { readFileSync } from "node:fs";

const [repo, site] = process.argv.slice(2);
const bundleIdentifier = "io.github.friederichvonstoeren.betternotes";
const description = "Handwritten notes for iPad with an open file format. No account, no telemetry, no subscription.";

const versions = JSON.parse(readFileSync(0, "utf8"))
  // v0.0.1 and v0.1 were built before the version number came from the tag: SideStore would see a mismatch.
  .filter((r) => !r.draft && !["v0.0.1", "v0.1"].includes(r.tag_name))
  .flatMap((r) => {
    const ipa = r.assets.find((a) => a.name === "betternotes.ipa");
    if (!ipa) return [];
    return [{
      version: r.tag_name.replace(/^v/, ""),
      date: r.published_at,
      localizedDescription: (r.body || r.name || r.tag_name).slice(0, 1000),
      downloadURL: ipa.browser_download_url,
      size: ipa.size,
      minOSVersion: "18.0",
    }];
  });

const latest = versions[0];
console.log(JSON.stringify({
  name: "betternotes",
  identifier: bundleIdentifier + ".source",
  subtitle: "Open handwriting notes",
  website: `https://github.com/${repo}`,
  iconURL: `${site}/icon.png`,
  apps: [{
    name: "betternotes",
    bundleIdentifier,
    developerName: "betternotes contributors",
    subtitle: "Open handwriting notes",
    localizedDescription: description,
    iconURL: `${site}/icon.png`,
    tintColor: "#7f6df2",
    versions,
    // Older store versions read these instead of `versions`.
    ...(latest && { version: latest.version, versionDate: latest.date, versionDescription: latest.localizedDescription, downloadURL: latest.downloadURL, size: latest.size }),
    appPermissions: { entitlements: [], privacy: {} },
  }],
  news: [],
}, null, 2));
