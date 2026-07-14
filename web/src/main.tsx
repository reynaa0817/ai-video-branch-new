import { useState } from 'react';
import { createRoot } from 'react-dom/client';
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
  { name: '成片', status: 'blocked', label: '等待质量门' },
];

const navItems = ['作品', '任务中心', '资产库', '数据看板', '系统配置'];

function App() {
  const [copilotOpen, setCopilotOpen] = useState(false);
  const [notice, setNotice] = useState('工作台已就绪');

  const act = (message: string) => setNotice(message);

  return (
    <div className="app-shell">
      <nav className="sidebar" aria-label="全局导航" data-focus-area="navigation">
        <div className="brand">Frochy Studio</div>
        {navItems.map((item) => (
          <button className={`button nav-item ${item === '作品' ? 'primary' : 'ghost'}`} type="button" key={item} onClick={() => act(`已切换到${item}`)}>
            <span aria-hidden="true" className="nav-icon">{item.slice(0, 1)}</span>
            <span className="nav-label">{item}</span>
          </button>
        ))}
      </nav>

      <div className="workbench">
        <header className="status-bar">
          <div className="project-title">雾港霓虹谋杀案</div>
          <div className="save-state">已保存 · ViewRevision 12</div>
          <div className="budget-bar" role="img" aria-label="预算：已消耗 18%，已预留 12%，剩余 70%">
            <span className="spent" /><span className="held" /><span className="remaining" />
          </div>
          <button className="button secondary desktop-action" type="button" onClick={() => act('已暂停新增付费任务')}>暂停新增付费任务</button>
        </header>

        <section className="stage-rail" aria-label="六阶段轨道" data-focus-area="stages">
          {stages.map((stage) => (
            <button className={`stage ${stage.status}`} type="button" key={stage.name} onClick={() => act(`已选择${stage.name}阶段`)}>
              <span className="stage-icon" aria-hidden="true" />
              <span>{stage.name}</span>
              <small>{stage.label}</small>
            </button>
          ))}
        </section>

        <div className="surface">
          <main className="canvas" tabIndex={0} data-focus-area="canvas" aria-label="当前产出画布">
            <figure className="preview">
              <div className="preview-media">
                <img src={`${import.meta.env.BASE_URL}concept-frame.png`} alt="9:16 概念样片预览帧" className="preview-frame" />
                <span className="ai-badge">AI 生成内容</span>
              </div>
              <figcaption>播放与字幕占位：概念样片将在制作阶段提供可控播放和中文字幕。</figcaption>
            </figure>

            <section className="gate" aria-labelledby="gate-title">
              <h1 id="gate-title">创意简报确认</h1>
              <p>AI 已把原始 idea 扩写为创意锚点、核心冲突和概念样片方向。</p>
              <p>请判断这个方向是否值得继续，确认后才会进入下一阶段的高成本生成。</p>
              <div className="actions">
                <button className="button primary" type="button" onClick={() => act('创意已确认，可以进入故事阶段')}>确认创意并继续</button>
                <button className="button secondary secondary-action" type="button" onClick={() => setCopilotOpen(true)}>告诉 AI 怎么改</button>
                <button className="button ghost secondary-action" type="button" onClick={() => act('已停留在创意阶段')}>暂时停在这里</button>
              </div>
            </section>
          </main>

          <button className="button copilot-toggle" type="button" aria-expanded={copilotOpen} aria-controls="copilot-panel" onClick={() => setCopilotOpen((value) => !value)}>
            {copilotOpen ? '关闭 AI 共创' : '打开 AI 共创'}
          </button>
          {copilotOpen && <button className="copilot-backdrop" type="button" aria-label="关闭 AI 共创面板" onClick={() => setCopilotOpen(false)} />}
          <aside id="copilot-panel" className={`copilot ${copilotOpen ? 'open' : ''}`} aria-label="AI 共创面板" data-focus-area="copilot">
            <div className="copilot-heading">
              <h2>正在修改：创意阶段 / 概念样片</h2>
              <button className="button ghost copilot-close" type="button" onClick={() => setCopilotOpen(false)}>关闭</button>
            </div>
            <p>本次将遵循 6 条已锁定设定。高成本动作会先展示影响和最大成本。</p>
            <label htmlFor="copilot-feedback">给 AI 的自然语言反馈</label>
            <textarea id="copilot-feedback" placeholder="描述你想调整的故事感觉" rows={4} />
            <button className="button primary" type="button" onClick={() => act('修改方案已加入任务队列')}>生成修改方案</button>
          </aside>
        </div>

        <section className="task-drawer" aria-label="生产任务抽屉" aria-live="polite" tabIndex={0} data-focus-area="tasks">
          <span>12 个镜头生成中 · 下一预览预计 4 分钟 · 已预留 ¥120</span>
          <span className="notice">{notice}</span>
        </section>
      </div>
    </div>
  );
}

const mount = document.querySelector<HTMLElement>('#app');
if (!mount) throw new Error('app mount point missing');
createRoot(mount).render(<App />);
