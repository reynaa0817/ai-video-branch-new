import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = path.resolve(import.meta.dirname, '..');
const reportFile = path.resolve(root, '..', 'reports', 'ui-state', 'UI-STATE-001', 'static-result.tsv');
const results = [];
let failed = false;

function check(name, action, detail) {
  try {
    if (!action()) throw new Error(detail);
    results.push(`${name}\tPASS\t${detail}`);
  } catch (error) {
    failed = true;
    results.push(`${name}\tFAIL\t${error instanceof Error ? error.message : String(error)}`);
  }
}

const files = {
  packageJson: path.join(root, 'package.json'),
  lockfile: path.join(root, 'pnpm-lock.yaml'),
  main: path.join(root, 'src', 'main.tsx'),
  css: path.join(root, 'src', 'styles.css'),
  html: path.join(root, 'index.html'),
  asset: path.join(root, 'public', 'concept-frame.png'),
  playwright: path.join(root, 'playwright.config.ts'),
};

for (const [name, file] of Object.entries(files)) {
  check(`file-${name}`, () => fs.statSync(file).isFile(), path.relative(root, file));
}

let packageJson = {};
check('package-json', () => {
  packageJson = JSON.parse(fs.readFileSync(files.packageJson, 'utf8'));
  return true;
}, 'package.json parses');
check('node-version', () => packageJson.engines?.node === '24.18.0', 'Node engine is locked to 24.18.0');
check('pnpm-version', () => packageJson.packageManager === 'pnpm@11.4.0', 'pnpm is locked to 11.4.0');
check('react-version', () => packageJson.dependencies?.react === '19.2.7' && packageJson.dependencies?.['react-dom'] === '19.2.7', 'React and ReactDOM are locked to 19.2.7');
check('browser-tests', () => packageJson.devDependencies?.['@playwright/test'] === '1.61.1' && packageJson.devDependencies?.['@axe-core/playwright'] === '4.12.1', 'Playwright and axe are exact dependencies');

let main = '';
let css = '';
check('main-readable', () => { main = fs.readFileSync(files.main, 'utf8'); return true; }, 'src/main.tsx is readable');
check('css-readable', () => { css = fs.readFileSync(files.css, 'utf8'); return true; }, 'src/styles.css is readable');
check('react-root', () => main.includes('createRoot(mount).render(<App />)'), 'React owns the mounted application');
check('responsive-drawer', () => main.includes('copilotOpen') && css.includes('.copilot.open'), 'responsive copilot has an explicit open/close path');
check('base-aware-asset', () => main.includes('import.meta.env.BASE_URL'), 'preview asset respects the Vite base path');
check('reduced-motion', () => css.includes('prefers-reduced-motion'), 'reduced-motion override exists');

fs.mkdirSync(path.dirname(reportFile), { recursive: true });
const temporary = `${reportFile}.${process.pid}.tmp`;
fs.writeFileSync(temporary, `check\tstatus\tdetail\n${results.join('\n')}\n`);
fs.renameSync(temporary, reportFile);
console.log(results.join('\n'));
if (failed) process.exit(1);
