import { createElement } from 'react';
import './styles.css';

type Stage = {
  name: string;
  status: 'complete' | 'current' | 'preview' | 'blocked' | 'todo';
  label: string;
};

const stages: Stage[] = [
  { name: '创意', status: 'current', label: '需要确认' },
  { name: '故事', status: 'todo', label: '未开始' },
  { name: '视觉', status: 'todo', label: '未开始' },
  { name: '制作', status: 'preview', label: '可预览' },
  { name: '后期', status: 'todo', label: '未开始' },
  { name: '成片', status: 'blocked', label: '等待质量门' }
];

const navItems = ['作品', '任务中心', '资产库', '数据看板', '系统配置'];

const root = document.querySelector<HTMLElement>('#app');
if (!root) {
  throw new Error('app mount point missing');
}

function el<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  className: string,
  text?: string
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text) node.textContent = text;
  return node;
}

function button(label: string, variant: 'primary' | 'secondary' | 'ghost' = 'secondary'): HTMLButtonElement {
  const node = document.createElement('button');
  node.className = `button ${variant}`;
  node.type = 'button';
  node.textContent = label;
  return node;
}

function renderNav(): HTMLElement {
  const nav = el('nav', 'sidebar');
  nav.setAttribute('aria-label', '全局导航');
  const brand = el('div', 'brand', 'Frochy Studio');
  nav.append(brand);
  for (const item of navItems) {
    const entry = button(item, item === '作品' ? 'primary' : 'ghost');
    entry.classList.add('nav-item');
    nav.append(entry);
  }
  return nav;
}

function renderStatusBar(): HTMLElement {
  const bar = el('header', 'status-bar');
  bar.append(el('div', 'project-title', '雾港霓虹谋杀案'));
  bar.append(el('div', 'save-state', '已保存 · ViewRevision 12'));
  const budget = el('div', 'budget-bar');
  budget.setAttribute('aria-label', '预算：已消耗 18%，已预留 12%，剩余 70%');
  budget.innerHTML = '<span class="spent"></span><span class="held"></span><span class="remaining"></span>';
  bar.append(budget);
  bar.append(button('暂停新增付费任务', 'secondary'));
  return bar;
}

function renderStages(): HTMLElement {
  const rail = el('section', 'stage-rail');
  rail.setAttribute('aria-label', '六阶段轨道');
  for (const stage of stages) {
    const item = el('button', `stage ${stage.status}`);
    item.type = 'button';
    item.innerHTML = `<span class="stage-icon" aria-hidden="true"></span><span>${stage.name}</span><small>${stage.label}</small>`;
    rail.append(item);
  }
  return rail;
}

function renderCanvas(): HTMLElement {
  const canvas = el('main', 'canvas');
  canvas.tabIndex = -1;
  const preview = el('section', 'preview');
  const frame = document.createElement('img');
  frame.src = '/concept-frame.png';
  frame.alt = '9:16 概念样片预览帧，带 AI 生成内容标识';
  frame.className = 'preview-frame';
  const badge = el('span', 'ai-badge', 'AI 生成内容');
  preview.append(frame, badge);

  const gate = el('section', 'gate');
  gate.setAttribute('aria-labelledby', 'gate-title');
  gate.append(el('h2', '', '创意简报确认'));
  gate.querySelector('h2')?.setAttribute('id', 'gate-title');
  gate.append(el('p', '', 'AI 已把原始 idea 扩写为创意锚点、核心冲突和概念样片方向。'));
  gate.append(el('p', '', '请判断这个方向是否值得继续，确认后才会进入下一阶段的高成本生成。'));
  const actions = el('div', 'actions');
  actions.append(button('确认创意并继续', 'primary'), button('告诉 AI 怎么改'), button('暂时停在这里', 'ghost'));
  gate.append(actions);

  canvas.append(preview, gate);
  return canvas;
}

function renderCopilot(): HTMLElement {
  const aside = el('aside', 'copilot');
  aside.setAttribute('aria-label', 'AI 共创面板');
  aside.append(el('h2', '', '正在修改：创意阶段 / 概念样片'));
  aside.append(el('p', '', '本次将遵循 6 条已锁定设定。高成本动作会先展示影响和最大成本。'));
  const input = document.createElement('textarea');
  input.placeholder = '描述你想调整的故事感觉';
  input.rows = 4;
  input.setAttribute('aria-label', '给 AI 的自然语言反馈');
  aside.append(input, button('生成修改方案', 'primary'));
  return aside;
}

function renderTaskDrawer(): HTMLElement {
  const drawer = el('section', 'task-drawer');
  drawer.setAttribute('aria-label', '生产任务抽屉');
  drawer.setAttribute('aria-live', 'polite');
  drawer.textContent = '12 个镜头生成中 · 下一预览预计 4 分钟 · 已预留 ¥120';
  return drawer;
}

const appShell = el('div', 'app-shell');
appShell.append(renderNav());
const workbench = el('div', 'workbench');
workbench.append(renderStatusBar(), renderStages());
const surface = el('div', 'surface');
surface.append(renderCanvas(), renderCopilot());
workbench.append(surface, renderTaskDrawer());
appShell.append(workbench);
root.append(appShell);

// Keep React present in the bundle without routing rendering through a custom framework.
createElement('span', { hidden: true }, 'react-shell');
