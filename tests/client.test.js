const { Client } = require('../index');

const client = new Client('http://127.0.0.1:8000');

client.connect('test-client')
    .then(() => {
        console.log('Клиент подключен к серверу');
        
        return client.emit('test', { 
            sender: 'test-client',
            message: 'Тестовое сообщение',
            timestamp: new Date().toISOString()
        });
    })
    .then(() => {
        console.log('Тестовое сообщение отправлено');
        
        setInterval(() => {
            client.checkMessages()
                .then(response => {
                    if (response.status === 'success') {
                        console.log('Получен ответ от сервера:', response.message);
                    }
                })
                .then(response => {
                    if (response && response.status === 'disconnected') {
                        console.log('Клиент отключен от сервера');
                        process.exit(0);
                    }
                })
                .catch(err => {
                    console.error('Ошибка:', err);
                });
        }, 1000);
    })
    .catch(err => {
        console.error('Ошибка при подключении:', err);
    }); 