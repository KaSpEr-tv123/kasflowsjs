declare module 'kasflowsjs' {
  export class KasflowsBase {
    constructor();
    on(event: string, callback: (data: any) => void): void;
    off(event: string): void;
    emit(event: string, data: any): void;
    messageforclient: Record<string, any>;
  }

  export class Client extends KasflowsBase {
    constructor(url: string);
    url: string;
    name: string | null;
    connected: boolean;
    token: string | null;
    pingInterval: NodeJS.Timeout | null;
    
    connect(name: string): Promise<any>;
    disconnect(): Promise<any>;
    checkMessages(): Promise<any>;
    startPing(): void;
    emit(event: string, data: any): Promise<any>;
  }

  export class Server {
    constructor(host: string, port: number);
    host: string;
    port: number;
    app: any;
    connections: Record<string, { 
        time: Date;
        token: string;
        ip: string;
    }>;
    kasflows: KasflowsBase;
    
    setupRoutes(): void;
    startDisconnectChecker(): void;
    start(): Promise<any>;
  }

  export const Kasflows: KasflowsBase;
  export const VERSION: string;
  
  export const logger: {
    setLogLevel(level: string): void;
    debug(message: string, ...args: any[]): void;
    info(message: string, ...args: any[]): void;
    warn(message: string, ...args: any[]): void;
    error(message: string, ...args: any[]): void;
    LOG_LEVELS: {
      DEBUG: string;
      INFO: string;
      WARN: string;
      ERROR: string;
    };
  };
} 