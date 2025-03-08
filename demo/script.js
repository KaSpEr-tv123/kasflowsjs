document.addEventListener('DOMContentLoaded', () => {
    const serverUrlInput = document.getElementById('server-url');
    const clientNameInput = document.getElementById('client-name');
    const connectBtn = document.getElementById('connect-btn');
    const disconnectBtn = document.getElementById('disconnect-btn');
    const eventNameInput = document.getElementById('event-name');
    const messageDataInput = document.getElementById('message-data');
    const sendBtn = document.getElementById('send-btn');
    const messageLog = document.getElementById('message-log');
    const clearLogBtn = document.getElementById('clear-log-btn');
    
    let client = null;
    let checkMessagesInterval = null;
    
    // Функция для добавления записи в лог
    function addLogEntry(message, type = 'info') {
        const entry = document.createElement('div');
        entry.className = `log-entry log-${type}`;
        entry.textContent = `[${new Date().toLocaleTimeString()}] ${message}`;
        messageLog.appendChild(entry);
        messageLog.scrollTop = messageLog.scrollHeight;
    }
    
    // Подключение к серверу
    connectBtn.addEventListener('click', async () => {
        const serverUrl = serverUrlInput.value.trim();
        const clientName = clientNameInput.value.trim();
        
        if (!serverUrl || !clientName) {
            addLogEntry('Укажите URL сервера и имя клиента', 'error');
            return;
        }
        
        try {
            addLogEntry(`Подключение к ${serverUrl} как ${clientName}...`);
            
            // Создаем клиент
            client = {
                url: serverUrl,
                name: clientName,
                connected: false,
                token: null,
                
                // Подключение к серверу
                async connect() {
                    const response = await fetch(`${this.url}/statusws`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ name: this.name })
                    });
                    
                    const data = await response.json();
                    if (data.status === 'connected' || data.status === 'already connected') {
                        this.connected = true;
                        this.token = data.token;
                    }
                    return data;
                },
                
                // Отключение от сервера
                async disconnect() {
                    const response = await fetch(`${this.url}/disconnect`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ name: this.name, token: this.token })
                    });
                    
                    const data = await response.json();
                    if (data.status === 'disconnected') {
                        this.connected = false;
                        this.token = null;
                    }
                    return data;
                },
                
                // Отправка сообщения
                async emit(event, data) {
                    if (!this.connected) {
                        return { status: 'not connected' };
                    }
                    
                    // Добавляем токен к данным
                    const dataWithToken = {
                        ...data,
                        token: this.token
                    };
                    
                    const response = await fetch(`${this.url}/sendmessage`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ event, data: dataWithToken })
                    });
                    
                    return response.json();
                },
                
                // Проверка сообщений
                async checkMessages() {
                    const response = await fetch(`${this.url}/getmessage`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ name: this.name, token: this.token })
                    });
                    
                    return response.json();
                }
            };
            
            // Подключаемся к серверу
            const response = await client.connect();
            
            if (response.status === 'connected' || response.status === 'already connected') {
                addLogEntry(`Подключено к серверу: ${response.status}`, 'success');
                
                // Включаем/отключаем кнопки
                connectBtn.disabled = true;
                disconnectBtn.disabled = false;
                sendBtn.disabled = false;
                
                // Запускаем проверку сообщений
                checkMessagesInterval = setInterval(async () => {
                    try {
                        const response = await client.checkMessages();
                        
                        if (response.status === 'success') {
                            addLogEntry(`Получено сообщение: ${JSON.stringify(response.message)}`, 'success');
                        }
                    } catch (error) {
                        addLogEntry(`Ошибка при проверке сообщений: ${error.message}`, 'error');
                    }
                }, 1000);
            } else {
                addLogEntry(`Ошибка подключения: ${response.status}`, 'error');
            }
        } catch (error) {
            addLogEntry(`Ошибка: ${error.message}`, 'error');
        }
    });
    
    // Отключение от сервера
    disconnectBtn.addEventListener('click', async () => {
        if (!client || !client.connected) {
            addLogEntry('Клиент не подключен', 'error');
            return;
        }
        
        try {
            clearInterval(checkMessagesInterval);
            
            const response = await client.disconnect();
            
            if (response.status === 'disconnected') {
                addLogEntry('Отключено от сервера', 'success');
                
                // Включаем/отключаем кнопки
                connectBtn.disabled = false;
                disconnectBtn.disabled = true;
                sendBtn.disabled = true;
            } else {
                addLogEntry(`Ошибка отключения: ${response.status}`, 'error');
            }
        } catch (error) {
            addLogEntry(`Ошибка: ${error.message}`, 'error');
        }
    });
    
    // Отправка сообщения
    sendBtn.addEventListener('click', async () => {
        if (!client || !client.connected) {
            addLogEntry('Клиент не подключен', 'error');
            return;
        }
        
        const eventName = eventNameInput.value.trim();
        let messageData;
        
        try {
            messageData = JSON.parse(messageDataInput.value);
        } catch (error) {
            addLogEntry('Некорректный JSON', 'error');
            return;
        }
        
        try {
            addLogEntry(`Отправка сообщения: ${eventName} ${JSON.stringify(messageData)}`);
            
            const response = await client.emit(eventName, messageData);
            
            if (response.status === 'success') {
                addLogEntry('Сообщение отправлено', 'success');
            } else {
                addLogEntry(`Ошибка отправки: ${response.status}`, 'error');
            }
        } catch (error) {
            addLogEntry(`Ошибка: ${error.message}`, 'error');
        }
    });
    
    // Очистка лога
    clearLogBtn.addEventListener('click', () => {
        messageLog.innerHTML = '';
    });
    
    // Инициализация
    addLogEntry('Демо-клиент KasFlows готов к работе');
}); 