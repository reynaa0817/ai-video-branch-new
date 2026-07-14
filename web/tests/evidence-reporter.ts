import fs from 'node:fs';
import path from 'node:path';
import type { FullResult, Reporter, Suite, TestCase, TestResult } from '@playwright/test/reporter';

type EvidenceRow = { name: string; status: string; detail: string };

export default class EvidenceReporter implements Reporter {
  private readonly rows = new Map<string, EvidenceRow[]>();

  onBegin(_config: unknown, suite: Suite) {
    this.rows.set('A11Y', []);
    this.rows.set('UI', []);
    for (const test of suite.allTests()) {
      const group = this.group(test.title);
      if (group) this.rows.get(group)?.push({ name: test.title, status: 'NOT_RUN', detail: 'test did not complete' });
    }
    this.write();
  }

  onTestEnd(test: TestCase, result: TestResult) {
    const group = this.group(test.title);
    if (!group) return;
    const current = this.rows.get(group)?.find((row) => row.name === test.title);
    const detail = result.error?.message?.split('\n')[0] ?? `${result.duration}ms`;
    if (current) Object.assign(current, { status: result.status === 'passed' ? 'PASS' : 'FAIL', detail });
    this.write();
  }

  onEnd(_result: FullResult) {
    this.write();
  }

  private group(title: string) {
    if (title.startsWith('[A11Y]')) return 'A11Y';
    if (title.startsWith('[UI]')) return 'UI';
    return undefined;
  }

  private write() {
    const root = path.resolve(process.cwd(), '..', 'reports');
    const targets = [
      { group: 'A11Y', file: path.join(root, 'a11y', 'A11Y-001', 'result.tsv') },
      { group: 'UI', file: path.join(root, 'ui-state', 'UI-STATE-001', 'result.tsv') },
    ];
    const staged = [];
    for (const target of targets) {
      fs.mkdirSync(path.dirname(target.file), { recursive: true });
      const temporary = `${target.file}.${process.pid}.tmp`;
      const rows = this.rows.get(target.group) ?? [];
      const body = rows.map((row) => `${row.name}\t${row.status}\t${row.detail.replaceAll('\t', ' ')}`).join('\n');
      fs.writeFileSync(temporary, `check\tstatus\tdetail\n${body}\n`);
      staged.push({ file: target.file, temporary });
    }
    for (const target of staged) fs.renameSync(target.temporary, target.file);
  }
}
