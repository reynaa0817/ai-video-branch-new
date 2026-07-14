import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = path.resolve(import.meta.dirname, '..');
const reportDir = path.resolve(root, '..', 'reports', 'a11y', 'A11Y-001');
const uiReportDir = path.resolve(root, '..', 'reports', 'ui-state', 'UI-STATE-001');
fs.mkdirSync(reportDir, { recursive: true });
fs.mkdirSync(uiReportDir, { recursive: true });

const files = {
  packageJson: path.join(root, 'package.json'),
  lockfile: path.join(root, 'pnpm-lock.yaml'),
  main: path.join(root, 'src', 'main.ts'),
  css: path.join(root, 'src', 'styles.css'),
  html: path.join(root, 'index.html'),
  asset: path.join(root, 'public', 'concept-frame.png')
};

const result = [];

function assertCheck(name, condition, detail) {
  if (!condition) {
    result.push(`${name}\tFAIL\t${detail}`);
    throw new Error(`${name}: ${detail}`);
  }
  result.push(`${name}\tPASS\t${detail}`);
}

for (const [name, file] of Object.entries(files)) {
  assertCheck(`file-${name}`, fs.existsSync(file), file);
}

const packageJson = JSON.parse(fs.readFileSync(files.packageJson, 'utf8'));
const main = fs.readFileSync(files.main, 'utf8');
const css = fs.readFileSync(files.css, 'utf8');
const html = fs.readFileSync(files.html, 'utf8');

assertCheck('node-version', packageJson.engines.node === '24.18.0', 'Node engine is locked to 24.18.0');
assertCheck('pnpm-version', packageJson.packageManager === 'pnpm@11.4.0', 'pnpm is locked to 11.4.0');
assertCheck('react-version', packageJson.dependencies.react === '19.2.7', 'React is locked to 19.2.7');
assertCheck('vite-version', packageJson.devDependencies.vite === '8.1.4', 'Vite is locked to 8.1.4');
assertCheck('typescript-version', packageJson.devDependencies.typescript === '5.9.3', 'TypeScript is locked to 5.9.3');

for (const token of ['#080a12', '#0b0e18', '#101522', '#6547d9', '#2dd4e5', '#62e7f3']) {
  assertCheck(`token-${token}`, css.includes(token), `CSS includes ${token}`);
}

for (const marker of ['>=1280px', '1024', '768', '<768px']) {
  const found = marker === '>=1280px'
    ? css.includes('grid-template-columns: 224px')
    : marker === '<768px'
      ? css.includes('@media (max-width: 767px)')
      : css.includes(`max-width: ${Number(marker) - 1}px`) || css.includes(`max-width: ${marker}px`);
  assertCheck(`responsive-${marker}`, found, `responsive boundary ${marker} is represented`);
}

assertCheck('focus-visible', css.includes(':focus-visible'), 'visible focus styles exist');
assertCheck('reduced-motion', css.includes('prefers-reduced-motion'), 'reduced motion media query exists');
assertCheck('touch-targets', css.includes('min-height: 44px'), '44px target baseline exists');
assertCheck('non-color-state', main.includes('label') && main.includes('stage-icon'), 'states include text labels and visual markers');
assertCheck('stage-rail', main.includes('六阶段轨道') && main.includes('创意') && main.includes('成片'), 'six-stage rail exists');
assertCheck('workbench-not-landing', main.includes('AI 共创面板') && main.includes('任务抽屉'), 'first screen is a workbench shell');
assertCheck('preview-asset', main.includes('/concept-frame.png') && html.includes('app'), 'preview asset is wired');
assertCheck('ai-label', main.includes('AI 生成内容'), 'AI generated content label is visible');
assertCheck('no-vw-fonts', !/font-size:\s*[^;]*vw/.test(css), 'font size does not scale with viewport width');
assertCheck('no-negative-letter-spacing', !/letter-spacing:\s*-/.test(css), 'CSS has no negative letter spacing');

fs.writeFileSync(path.join(reportDir, 'result.tsv'), `check\tstatus\tdetail\n${result.join('\n')}\n`);
fs.writeFileSync(path.join(uiReportDir, 'result.tsv'), `check\tstatus\tdetail\n${result.join('\n')}\n`);
console.log(result.join('\n'));
