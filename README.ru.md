# KasFlows

KasFlows - это легковесная система коммуникации, специально разработанная для Roblox скриптов как альтернатива WebSocket. Она предоставляет простой и гибкий способ обработки клиент-серверной коммуникации через API сервер.

## Установка

```bash
npm install kasflowsjs
```

## Использование

### Базовое использование (как в Python версии)

```javascript
const { Kasflows } = require('kasflowsjs');

// Подписка на события
Kasflows.on('message', (data) => {
    console.log('Получено сообщение:', data);
});

// Отправка события
Kasflows.emit('message', { text: 'Привет, мир!' });

// Отписка от события
Kasflows.off('message');
```

### Создание сервера

```javascript
const { Server } = require('kasflowsjs');

const server = new Server('127.0.0.1', 8000);

// Подписка на системные события
server.kasflows.on('connect', (data) => {
    console.log('Клиент подключился:', data);
});

server.kasflows.on('disconnect', (data) => {
    console.log('Клиент отключился:', data);
});

// Запуск сервера
server.start().then(() => {
    console.log('Сервер успешно запущен');
});
```

### Использование клиента

```javascript
const { Client } = require('kasflowsjs');

const client = new Client('http://localhost:8000');

// Подключение к серверу
client.connect('my-client-name').then(() => {
    console.log('Подключено к серверу');
    
    // Подписка на события
    client.on('message', (data) => {
        console.log('Получено сообщение:', data);
    });
    
    // Отправка сообщения
    client.emit('message', { text: 'Привет от клиента!' });
    
    // Проверка сообщений от сервера
    setInterval(() => {
        client.checkMessages().then(response => {
            if (response.status === 'success') {
                console.log('Получено сообщение от сервера:', response.message);
            }
        });
    }, 1000);
});

// Отключение от сервера
// client.disconnect().then(() => console.log('Отключено от сервера'));
```

### Использование в Roblox

```lua
local KasflowsClient = require("kasflows")
local client = KasflowsClient.new("http://localhost:8000")

client:connect("roblox-client")

client:on("message", function(data)
    print("Получено сообщение:", data)
end)

-- Проверка сообщений от сервера
spawn(function()
    while wait(1) do
        local response = client:checkMessages()
        if response.status == "success" then
            print("Получено сообщение от сервера:", response.message)
        end
    end
end)
```

### Настройка логирования

```javascript
const { logger } = require('kasflowsjs');

// Установка уровня логирования
logger.setLogLevel(logger.LOG_LEVELS.DEBUG); // DEBUG, INFO, WARN, ERROR

// Использование логгера
logger.debug('Отладочное сообщение');
logger.info('Информационное сообщение');
logger.warn('Предупреждение');
logger.error('Ошибка', { details: 'Дополнительная информация' });
```

## API

### Класс KasflowsBase

#### on(event, callback)
Подписка на событие.

#### off(event)
Отписка от события.

#### emit(event, data)
Отправка события.

### Класс Server

#### constructor(host = '127.0.0.1', port = 8000)
Создание нового сервера.

#### start()
Запуск сервера. Возвращает Promise.

### Класс Client

#### constructor(url)
Создание нового клиента.

#### connect(name)
Подключение к серверу с указанным именем. Возвращает Promise.

#### disconnect()
Отключение от сервера. Возвращает Promise.

#### on(event, callback)
Подписка на событие.

#### off(event)
Отписка от события.

#### emit(event, data)
Отправка события на сервер. Возвращает Promise.

#### checkMessages()
Проверка наличия сообщений от сервера. Возвращает Promise.

### Система логирования

#### logger.setLogLevel(level)
Установка уровня логирования (DEBUG, INFO, WARN, ERROR).

#### logger.debug(message, ...args)
Вывод отладочного сообщения.

#### logger.info(message, ...args)
Вывод информационного сообщения.

#### logger.warn(message, ...args)
Вывод предупреждения.

#### logger.error(message, ...args)
Вывод сообщения об ошибке.

### Серверные эндпоинты

- `POST /statusws` - Подключение и проверка статуса клиента
- `POST /sendmessage` - Отправка сообщения
- `POST /getmessage` - Получение сообщений
- `POST /sendmessagetoclient` - Отправка сообщения конкретному клиенту
- `POST /disconnect` - Отключение клиента
- `GET /getclients` - Получение списка подключенных клиентов

## Преимущества

- Полная совместимость с Python версией библиотеки
- Поддержка событийной модели
- Простой API для клиента и сервера
- Автоматическое управление подключениями
- Поддержка отправки сообщений конкретным клиентам
- Легкая интеграция с Roblox
- Гибкая система логирования

## Тестирование

Библиотека включает набор тестов для проверки функциональности:

```bash
# Запуск сервера для тестирования
node tests/server.test.js

# В другом терминале запустите клиент
node tests/client.test.js

# Запуск автоматизированных тестов (требуется Jest)
npm test
```

## Лицензия

MIT 