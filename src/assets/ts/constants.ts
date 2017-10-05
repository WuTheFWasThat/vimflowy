import { ServerConfig } from '../../shared/server_config';

declare const window: any;

// available through webpack definitions
declare const INJECTED_SERVER_CONFIG: ServerConfig;

export const SERVER_CONFIG: ServerConfig = INJECTED_SERVER_CONFIG;
window.SERVER_CONFIG = INJECTED_SERVER_CONFIG;
