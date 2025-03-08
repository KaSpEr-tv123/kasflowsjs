const { KasflowsBase, Client, Server } = require('../index');
const fetch = require('node-fetch');

// Мокаем fetch для тестирования клиента
jest.mock('node-fetch');

describe('KasflowsBase', () => {
    let kasflows;
    
    beforeEach(() => {
        kasflows = new KasflowsBase();
    });
    
    test('должен регистрировать и вызывать обработчики событий', () => {
        const mockCallback = jest.fn();
        const testData = { test: 'data' };
        
        kasflows.on('test', mockCallback);
        kasflows.emit('test', testData);
        
        expect(mockCallback).toHaveBeenCalledWith(testData);
    });
    
    test('должен удалять обработчики событий', () => {
        const mockCallback = jest.fn();
        
        kasflows.on('test', mockCallback);
        kasflows.off('test');
        
        // Не ожидаем исключения, просто проверяем, что колбэк не вызван
        kasflows.emit('test', {});
        expect(mockCallback).not.toHaveBeenCalled();
    });
});

describe('Client', () => {
    let client;
    
    beforeEach(() => {
        client = new Client('http://test-server');
        fetch.mockResolvedValue({
            json: () => Promise.resolve({ status: 'success' })
        });
    });
    
    afterEach(() => {
        // Очищаем интервалы после каждого теста
        if (client.pingInterval) {
            clearInterval(client.pingInterval);
        }
    });
    
    test('должен подключаться к серверу', async () => {
        const result = await client.connect('test-client');
        
        expect(result.status).toBe('success');
        expect(client.connected).toBe(true);
        expect(client.name).toBe('test-client');
    });
    
    test('должен отключаться от сервера', async () => {
        client.connected = true;
        client.name = 'test-client';
        
        const result = await client.disconnect();
        
        expect(result.status).toBe('success');
        expect(client.connected).toBe(false);
        expect(client.name).toBe(null);
    });
});

// Очистка после всех тестов
afterAll(done => {
    // Очистка всех таймеров
    jest.useRealTimers();
    done();
}); 