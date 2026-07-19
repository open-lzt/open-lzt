# @open-lzt/ui

Typed React components over the `lzt-ui` CSS library. Every component is a thin
wrapper around the plain-CSS classes — no CSS-in-JS, no new runtime dependency,
behaviour is React state/hooks (it does **not** load `lzt-ui.js`).

## Install

```bash
npm install @open-lzt/ui react react-dom
```

```tsx
import '@open-lzt/ui/lzt-ui.css';
```

## Usage by group

**Theme**

```tsx
import { ThemeProvider, ThemeToggle, useTheme } from '@open-lzt/ui';

<ThemeProvider>
  <ThemeToggle />
</ThemeProvider>;
```

**Layout**

```tsx
import { Shell, Container, Main, Stack, Row, Grid, Divider, Spacer } from '@open-lzt/ui';

<Shell>
  <Container>
    <Row between>
      <span>Left</span>
      <Spacer />
      <span>Right</span>
    </Row>
  </Container>
</Shell>;
```

**Button**

```tsx
import { Button, ButtonGroup } from '@open-lzt/ui';

<ButtonGroup>
  <Button variant="primary" size="sm" loading>
    Save
  </Button>
  <Button variant="outline">Cancel</Button>
</ButtonGroup>;
```

**Icon**

```tsx
import { Icon } from '@open-lzt/ui';

<Icon name="bell" size={18} />;
```

**Forms**

```tsx
import { Field, Label, Hint, Input, Search, Switch } from '@open-lzt/ui';

<Field>
  <Label>Email</Label>
  <Input type="email" invalid />
  <Hint error>Required</Hint>
</Field>;
<Search placeholder="Search…" />;
<Switch label="Notify me" />;
```

**Display**

```tsx
import { Block, BlockHeader, BlockBody, Card, Stat, Badge, Avatar } from '@open-lzt/ui';

<Block>
  <BlockHeader>Stats</BlockHeader>
  <BlockBody>
    <Stat label="Users" value="1,204" delta="+4%" trend="up" />
  </BlockBody>
</Block>;
<Badge tone="brand" pill>New</Badge>;
<Avatar size="lg" status="online" />;
```

**Navigation**

```tsx
import { Tabs, Dropdown, Menu, MenuItem, Pagenav } from '@open-lzt/ui';

<Tabs items={[{ value: 'a', label: 'A' }, { value: 'b', label: 'B' }]} />;
<Dropdown trigger={<button>Actions</button>}>
  <Menu>
    <MenuItem>Edit</MenuItem>
    <MenuItem danger>Delete</MenuItem>
  </Menu>
</Dropdown>;
<Pagenav page={3} count={12} onChange={() => {}} />;
```

**Feedback**

```tsx
import { Modal, Progress, Spinner, Skeleton } from '@open-lzt/ui';

<Modal open={isOpen} onClose={close} title="Confirm">
  Are you sure?
</Modal>;
```

**Toasts**

```tsx
import { ToastProvider, useToast } from '@open-lzt/ui';

<ToastProvider>
  <App />
</ToastProvider>;

const { show } = useToast();
show('Saved', { tone: 'default' });
```

**Forum**

```tsx
import { Thread, ThreadMain, ThreadTitle, Post, PostContent, Spoiler, Reactions, Reaction } from '@open-lzt/ui';

<Thread unread>
  <ThreadMain>
    <ThreadTitle>Welcome thread</ThreadTitle>
  </ThreadMain>
</Thread>;
```

Plain-CSS / plain-HTML usage (no React, `data-lzt-*` behaviour via `lzt-ui.js`)
is documented in the parent [`../README.md`](../README.md).
