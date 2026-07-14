import fs from 'node:fs';
import path from 'node:path';
import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';

const viewports = [
  { name: 'desktop', width: 1440, height: 1000 },
  { name: 'compact', width: 1100, height: 900 },
  { name: 'tablet', width: 900, height: 900 },
  { name: 'mobile', width: 390, height: 844 },
];

for (const viewport of viewports) {
  test(`[A11Y] axe ${viewport.name} ${viewport.width}px`, async ({ page }) => {
    await page.setViewportSize(viewport);
    await page.goto('/');
    const results = await new AxeBuilder({ page }).analyze();
    expect(results.violations).toEqual([]);
  });

  test(`[UI] viewport ${viewport.name} ${viewport.width}px`, async ({ page }) => {
    await page.setViewportSize(viewport);
    await page.goto('/');
    await expect(page.getByRole('navigation', { name: '全局导航' })).toBeVisible();
    await expect(page.getByRole('region', { name: '六阶段轨道' })).toBeVisible();
    await expect(page.getByRole('main', { name: '当前产出画布' })).toBeVisible();
    await expect(page.getByRole('region', { name: '生产任务抽屉' })).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
    const badge = await page.locator('.ai-badge').boundingBox();
    const caption = await page.locator('.preview figcaption').boundingBox();
    expect((badge?.y ?? 0) + (badge?.height ?? 0)).toBeLessThanOrEqual(caption?.y ?? 0);

    const toggle = page.getByRole('button', { name: '打开 AI 共创' });
    const copilot = page.getByRole('complementary', { name: 'AI 共创面板' });
    if (viewport.width >= 1280) {
      await expect(copilot).toBeVisible();
      await expect(toggle).toBeHidden();
    } else if (viewport.width >= 768) {
      await expect(copilot).toBeHidden();
      await expect(toggle).toBeVisible();
      await toggle.click();
      await expect(copilot).toBeVisible();
      await page.getByRole('button', { name: '关闭', exact: true }).click();
      await expect(copilot).toBeHidden();
    } else {
      await expect(copilot).toBeHidden();
      await expect(toggle).toBeHidden();
      await expect(page.getByRole('button', { name: '确认创意并继续' })).toBeVisible();
      await expect(page.getByRole('button', { name: '告诉 AI 怎么改' })).toBeHidden();
    }

    const screenshotDir = path.resolve(process.cwd(), '..', 'reports', 'ui-state', 'UI-STATE-001');
    fs.mkdirSync(screenshotDir, { recursive: true });
    await page.screenshot({ path: path.join(screenshotDir, `viewport-${viewport.width}.png`), fullPage: true });
  });
}

test('[A11Y] keyboard order touch targets and reduced motion', async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/');

  const targets = page.locator('button:visible, textarea:visible, [tabindex="0"]:visible');
  for (let index = 0; index < await targets.count(); index += 1) {
    const box = await targets.nth(index).boundingBox();
    expect(box, `target ${index} has no box`).not.toBeNull();
    expect(box?.width ?? 0).toBeGreaterThanOrEqual(44);
    expect(box?.height ?? 0).toBeGreaterThanOrEqual(44);
  }

  const focusAreas = [];
  for (let index = 0; index < 40; index += 1) {
    await page.keyboard.press('Tab');
    const area = await page.evaluate(() => document.activeElement?.closest('[data-focus-area]')?.getAttribute('data-focus-area') ?? '');
    if (area && focusAreas.at(-1) !== area) focusAreas.push(area);
  }
  for (const required of ['navigation', 'stages', 'canvas', 'copilot', 'tasks']) expect(focusAreas).toContain(required);
  expect(focusAreas.indexOf('navigation')).toBeLessThan(focusAreas.indexOf('stages'));
  expect(focusAreas.indexOf('stages')).toBeLessThan(focusAreas.indexOf('canvas'));
  expect(focusAreas.indexOf('canvas')).toBeLessThan(focusAreas.indexOf('copilot'));
  expect(focusAreas.indexOf('copilot')).toBeLessThan(focusAreas.indexOf('tasks'));

  const motion = await page.locator('.button').first().evaluate((element) => getComputedStyle(element).transitionDuration);
  expect(motion === '0s' || motion === '0.001s').toBe(true);
});

test('[UI] mobile simple confirmation updates live status', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  await page.getByRole('button', { name: '确认创意并继续' }).click();
  await expect(page.getByText('创意已确认，可以进入故事阶段')).toBeVisible();
});
