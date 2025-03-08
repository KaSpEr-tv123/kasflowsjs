const { Server, Kasflows } = require('../index');

// Создаем сервер
const server = new Server('127.0.0.1', 8000);

// Подписываемся на события
server.kasflows.on('connect', (data) => {
    console.log(`Клиент ${data.name} подключился`);
});

server.kasflows.on('disconnect', (data) => {
    console.log(`Клиент ${data.name} отключился`);
});

server.kasflows.on('message', (data) => {
    console.log(`Получено сообщение от ${data.sender}:`, data.message);
    
    // Отправляем ответ клиенту
    server.kasflows.messageforclient[data.sender] = {
        type: 'response',
        message: `Сервер получил ваше сообщение: ${data.message}`,
        timestamp: new Date().toISOString()
    };
});

// Запускаем сервер
server.start().then(() => {
    console.log(`Сервер запущен на http://${server.host}:${server.port}`);
}); 