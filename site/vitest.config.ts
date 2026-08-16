import { fileURLToPath } from 'node:url';

import { defineConfig } from 'vitest/config';

export default defineConfig({
  // Тот же алиас, что у Next и у `tsconfig.json`. Без него `@/lib/...` не резолвится, и весь
  // файл тестов падает на СБОРЕ — то есть контракт флагов не проверяется вовсе, а выглядит это
  // как один красный тест, а не как отсутствие проверки.
  resolve: {
    alias: { '@': fileURLToPath(new URL('.', import.meta.url)) },
  },
  test: {
    include: ['tests/**/*.test.ts'],
  },
});
