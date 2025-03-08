const { Client } = require('kasflowsjs');

// Создаем клиент
const client = new Client('http://127.0.0.1:8000');

// Подключаемся к серверу
client.connect('example-client')
    .then((response) => {
        console.log('Подключен к серверу:', response);
        
        // Отправляем сообщение
        return client.emit('message', {
            sender: 'example-client',
            message: 'Привет, сервер!',
            timestamp: new Date().toISOString()
        });
    })
    .then(() => {
        console.log('Сообщение отправлено');
        
        // Проверяем ответ от сервера каждую секунду
        const interval = setInterval(() => {
            client.checkMessages()
                .then((response) => {
                    if (response.status === 'success') {
                        console.log('Получен ответ от сервера:', response.message);
                        clearInterval(interval);
                        
                        // Отключаемся от сервера
                        return client.disconnect();
                    }
                })
                .then((response) => {
                    if (response && response.status === 'disconnected') {
                        console.log('Отключен от сервера');
                        process.exit(0);
                    }
                })
                .catch((error) => {
                    console.error('Ошибка:', error);
                });
        }, 1000);
    })
    .catch((error) => {
        console.error('Ошибка при подключении:', error);
    }); 