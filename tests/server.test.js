const { Server } = require('../index');

// Создаем сервер
const server = new Server('127.0.0.1', 8000);

// Подписываемся на события в объекте server.kasflows, а не в глобальном Kasflows
server.kasflows.on('connect', (data) => {
    console.log('Клиент подключился:', data);
});

server.kasflows.on('disconnect', (data) => {
    console.log('Клиент отключился:', data);
});

server.kasflows.on('test', (data) => {
    console.log('Получено тестовое событие:', data);
    
    // Отправляем сообщение клиенту
    server.kasflows.messageforclient[data.sender] = {
        type: 'response',
        message: 'Сервер получил ваше сообщение',
        timestamp: new Date().toISOString()
    };
});

// Запускаем сервер
server.start().then(() => {
    console.log('Тестовый сервер запущен на http://127.0.0.1:8000');
}); 