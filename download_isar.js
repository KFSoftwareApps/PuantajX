const https = require('https');
const fs = require('fs');
const path = require('path');

const dest = path.join(__dirname, 'web', 'isar.wasm');
const buildDest = path.join(__dirname, 'build', 'web', 'isar.wasm');

// Ensure directories exist
if (!fs.existsSync(path.dirname(dest))) fs.mkdirSync(path.dirname(dest), { recursive: true });

const version = "3.1.0+1";
const baseVersion = "3.1.0"; // Try without build number

const urls = [
    `https://github.com/isar/isar/releases/download/${version}/isar.wasm`,
    `https://github.com/isar/isar/releases/download/v${version}/isar.wasm`,
    `https://github.com/isar/isar/releases/download/${baseVersion}/isar.wasm`,
    `https://github.com/isar/isar/releases/download/v${baseVersion}/isar.wasm`,
    `https://unpkg.com/isar@${baseVersion}/dist/isar.wasm`
];

function download(url, destination) {
    return new Promise((resolve, reject) => {
        console.log(`Trying: ${url}`);
        const req = https.get(url, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                console.log(`Redirecting to: ${res.headers.location}`);
                download(res.headers.location, destination).then(resolve).catch(reject);
                return;
            }

            if (res.statusCode !== 200) {
                reject(new Error(`Status code: ${res.statusCode}`));
                return;
            }

            if (res.headers['content-type'] && res.headers['content-type'].includes('text/html')) {
                // GitHub 404s are often HTML
                reject(new Error('Received HTML instead of binary. Probably a 404 or login page.'));
                return;
            }

            const file = fs.createWriteStream(destination);
            res.pipe(file);

            file.on('finish', () => {
                file.close(() => {
                    const stats = fs.statSync(destination);
                    if (stats.size < 1000) {
                        reject(new Error(`File too small (${stats.size} bytes). Likely invalid.`));
                    } else {
                        resolve();
                    }
                });
            });
        });

        req.on('error', (err) => {
            reject(err);
        });
    });
}

async function main() {
    for (const url of urls) {
        try {
            await download(url, dest);
            console.log(`Success! Downloaded to ${dest}`);

            // Copy to build folder if it exists
            const buildWebDir = path.dirname(buildDest);
            if (fs.existsSync(buildWebDir)) {
                fs.copyFileSync(dest, buildDest);
                console.log(`Copied to ${buildDest}`);
            }
            return; // Exit on success
        } catch (err) {
            console.error(`Failed ${url}: ${err.message}`);
        }
    }
    console.error("All download attempts failed.");
    process.exit(1);
}

main();
