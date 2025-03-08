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
        // Проверяем, что строка существует в LOG_LEVELS
        if (LOG_LEVELS[level.toUpperCase()] !== undefined) {
            level = LOG_LEVELS[level.toUpperCase()];
        } else {
            console.warn(`[Logger] Неизвестный уровень логирования: ${level}. Используется INFO.`);
            level = LOG_LEVELS.INFO;
        }
    } else if (typeof level === 'number') {
        // Проверяем, что число в допустимом диапазоне
        if (level < 0 || level > 3) {
            console.warn(`[Logger] Недопустимый уровень логирования: ${level}. Используется INFO.`);
            level = LOG_LEVELS.INFO;
        }
    } else {
        console.warn(`[Logger] Недопустимый тип уровня логирования: ${typeof level}. Используется INFO.`);
        level = LOG_LEVELS.INFO;
    }
    
    currentLogLevel = level;
    debug(`Уровень логирования установлен на: ${getLogLevelName(level)}`);
}

// Вспомогательная функция для получения имени уровня логирования
function getLogLevelName(level) {
    for (const [name, value] of Object.entries(LOG_LEVELS)) {
        if (value === level) return name;
    }
    return 'UNKNOWN';
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

// Экспортируем объект с методами и константами
const logger = {
    debug,
    info,
    warn,
    error,
    setLogLevel,
    LOG_LEVELS
};

module.exports = logger; 