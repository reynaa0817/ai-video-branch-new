import { createElement } from 'react';

const app = document.querySelector<HTMLElement>('#app');
if (!app) throw new Error('fixture mount point missing');
const element = createElement('span', null, 'BASE-002');
app.textContent = String(element.props.children);
