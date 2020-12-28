import * as path from 'path';

export const publicPath = '/build/';

export const defaultSrcDir = path.join(__dirname, '../../src');
export const defaultStaticDir = path.join(__dirname, '../../', 'static');
export const defaultBuildDir = path.join(defaultStaticDir, 'build');

