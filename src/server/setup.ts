import * as path from 'path';

import * as express from 'express';

export function setupApp(app: express.Application, staticDir: string) {
  app.use(express.static(staticDir));

  app.get('/:docname', (_req, res) => {
    res.sendFile(path.join(staticDir, 'static/index.html'));
  });
}
