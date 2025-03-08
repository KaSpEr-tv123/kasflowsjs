// Простая система логирования для Kasflows

const LOG_LEVELS = {
    DEBUG: 0,
    INFO: 1,
    WARN: 2,
    ERROR: 3
};

let currentLogLevel = LOG_LEVELS.INFO;

function setLogLevel(level) {
    if (typeof level === 'string') {
        level = LOG_LEVELS[level.toUpperCase()];
    }
    
    if (level !== undefined) {
        currentLogLevel = level;
    }
}

function formatMessage(level, message, ...args) {
    const timestamp = new Date().toISOString();
    let formattedMessage = `[${timestamp}] [${level}] ${message}`;
    
    if (args.length > 0) {
        try {
            const argsStr = args.map(arg => 
                typeof arg === 'object' ? JSON.stringify(arg) : arg
            ).join(' ');
            formattedMessage += ' ' + argsStr;
        } catch (e) {
            formattedMessage += ' [Error formatting arguments]';
        }
    }
    
    return formattedMessage;
}

function debug(message, ...args) {
    if (currentLogLevel <= LOG_LEVELS.DEBUG) {
        console.debug(formatMessage('DEBUG', message, ...args));
    }
}

function info(message, ...args) {
    if (currentLogLevel <= LOG_LEVELS.INFO) {
        console.info(formatMessage('INFO', message, ...args));
    }
}

function warn(message, ...args) {
    if (currentLogLevel <= LOG_LEVELS.WARN) {
        console.warn(formatMessage('WARN', message, ...args));
    }
}

function error(message, ...args) {
    if (currentLogLevel <= LOG_LEVELS.ERROR) {
        console.error(formatMessage('ERROR', message, ...args));
    }
}

module.exports = {
    debug,
    info,
    warn,
    error,
    setLogLevel,
    LOG_LEVELS
}; 