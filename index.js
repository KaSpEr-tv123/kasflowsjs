const express = require('express');
const cors = require('cors');
const fetch = require('node-fetch');
const logger = require('./logger');

class KasflowsBase {
    constructor() {
        this.eventsCallbacks = {};
        this.messageforclient = {};
    }

    on(event, callback) {
        this.eventsCallbacks[event] = callback;
        logger.info(`Callback added for event '${event}'`);
    }

    off(event) {
        delete this.eventsCallbacks[event];
        logger.info(`Callback removed for event '${event}'`);
    }

    emit(event, data) {
        if (this.eventsCallbacks[event]) {
            this.eventsCallbacks[event](data);
            logger.info(`Event '${event}' emitted with data:`, data);
        } else {
            logger.warn(`No handler for event '${event}', ignoring`);
        }
    }
}

class Client extends KasflowsBase {
    constructor(url) {
        super();
        this.url = url;
        this.name = null;
        this.connected = false;
        this.pingInterval = null;
    }

    async connect(name) {
        this.name = name;
        
        const response = await fetch(`${this.url}/statusws`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ name })
        });
        
        const data = await response.json();
        
        if (data.status === 'connected' || data.status === 'already connected') {
            this.connected = true;
            this.token = data.token;
            this.startPing();
        }
        
        return data;
    }

    async disconnect() {
        if (!this.connected) {
            return { status: 'not connected' };
        }
        
        if (this.pingInterval) {
            clearInterval(this.pingInterval);
            this.pingInterval = null;
        }
        
        const response = await fetch(`${this.url}/disconnect`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ name: this.name, token: this.token })
        });
        
        const data = await response.json();
        
        if (data.status === 'disconnected') {
            this.connected = false;
            this.name = null;
            this.token = null;
        }
        
        return data;
    }

    startPing() {
        this.pingInterval = setInterval(() => {
            if (this.connected) {
                fetch(`${this.url}/statusws`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ name: this.name })
                })
                .then(response => response.json())
                .catch(err => {
                    logger.error(`Ping error: ${err.message}`);
                });
            }
        }, 5000);
    }

    async emit(event, data) {
        if (!this.connected) {
            return { status: 'not connected' };
        }
        
        const dataWithToken = {
            ...data,
            token: this.token
        };
        
        const response = await fetch(`${this.url}/sendmessage`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ event, data: dataWithToken })
        });
        
        return response.json();
    }

    async checkMessages() {
        if (!this.connected) {
            return { status: 'not connected' };
        }
        
        const response = await fetch(`${this.url}/getmessage`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ name: this.name, token: this.token })
        });
        
        return response.json();
    }
}

class Server {
    constructor(host = '127.0.0.1', port = 8000) {
        this.app = express();
        this.host = host;
        this.port = port;
        this.connections = {};
        this.kasflows = new KasflowsBase();

        this.setupMiddleware();
        this.setupRoutes();
        this.startDisconnectChecker();
    }

    setupMiddleware() {
        this.app.use(cors());
        this.app.use(express.json());
    }

    setupRoutes() {
        this.app.get('/', (req, res) => {
            res.json({
                name: 'Kasflows',
                version: VERSION,
                api: {
                    '/statusws': 'POST - Подключение клиента или обновление статуса',
                    '/disconnect': 'POST - Отключение клиента',
                    '/getmessage': 'POST - Получение сообщений для клиента',
                    '/sendmessage': 'POST - Отправка сообщения на сервер',
                    '/sendmessagetoclient': 'POST - Отправка сообщения конкретному клиенту',
                    '/getclients': 'GET - Получение списка подключенных клиентов'
                }
            });
        });

        this.app.post('/statusws', (req, res) => {
            const { name } = req.body;
            
            if (name in this.connections) {
                this.connections[name].time = new Date();
                logger.info(`Client ${name} pinged`);
                res.json({ status: 'already connected' });
            } else {
                this.connections[name] = { time: new Date() };
                this.kasflows.emit('connect', req.body);
                logger.info(`Client ${name} connected`);
                res.json({ status: 'connected' });
            }
        });

        this.app.post('/disconnect', (req, res) => {
            const { name } = req.body;
            
            if (name in this.connections) {
                delete this.connections[name];
                this.kasflows.emit('disconnect', req.body);
                logger.info(`Client ${name} disconnected`);
                res.json({ status: 'disconnected' });
            } else {
                res.json({ status: 'not connected' });
            }
        });

        this.app.post('/getmessage', (req, res) => {
            const { name } = req.body;
            
            if (name in this.kasflows.messageforclient) {
                const message = this.kasflows.messageforclient[name];
                delete this.kasflows.messageforclient[name];
                logger.info(`Message delivered to client ${name}`);
                res.json({ status: 'success', message });
            } else {
                res.json({ status: 'no message' });
            }
        });

        this.app.post('/sendmessage', (req, res) => {
            const { event, data } = req.body;
            try {
                if (data.sender && data.sender in this.connections) {
                    this.kasflows.emit(event, data);
                    res.json({ status: 'success' });
                } else {
                    res.status(400).json({ status: 'error', message: 'Client not found' });
                }
            } catch (error) {
                logger.error(`Error emitting event ${event}: ${error.message}`);
                res.status(400).json({ status: 'error', message: error.message });
            }
        });

        this.app.post('/sendmessagetoclient', (req, res) => {
            const { name, message } = req.body;
            this.kasflows.messageforclient[name] = message;
            logger.info(`Message queued for client ${name}`);
            res.json({ status: 'success' });
        });

        this.app.get('/getclients', (req, res) => {
            res.json({ clients: Object.keys(this.connections) });
        });
    }

    startDisconnectChecker() {
        setInterval(() => {
            const currentTime = new Date();
            const toDisconnect = [];

            for (const [name, info] of Object.entries(this.connections)) {
                const lastTime = info.time;
                if ((currentTime - lastTime) / 1000 > 10) {
                    toDisconnect.push(name);
                }
            }

            toDisconnect.forEach(name => {
                delete this.connections[name];
                logger.info(`Client ${name} disconnected due to timeout`);
                this.kasflows.emit('disconnect', { name });
            });
        }, 5000);
    }

    start() {
        return new Promise((resolve) => {
            const server = this.app.listen(this.port, this.host, () => {
                logger.info(`Server running at http://${this.host}:${this.port}`);
                resolve(server);
            });
        });
    }
}

const VERSION = '1.0.0';

const Kasflows = new KasflowsBase();

module.exports = {
    KasflowsBase,
    Client,
    Server,
    Kasflows,
    VERSION
};
