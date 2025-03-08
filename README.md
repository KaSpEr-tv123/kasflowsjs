# KasFlows

KasFlows is a lightweight communication system specifically designed for Roblox scripts as an alternative to WebSocket. It provides a simple and flexible way to handle client-server communication through an API server.

## Installation

```bash
npm install kasflowsjs
```

## Usage

### Basic Usage (similar to Python version)

```javascript
const { Kasflows } = require('kasflowsjs');

// Subscribe to events
Kasflows.on('message', (data) => {
    console.log('Received message:', data);
});

// Emit an event
Kasflows.emit('message', { text: 'Hello, world!' });

// Unsubscribe from an event
Kasflows.off('message');
```

### Creating a Server

```javascript
const { Server } = require('kasflowsjs');

const server = new Server('127.0.0.1', 8000);

// Subscribe to system events
server.kasflows.on('connect', (data) => {
    console.log('Client connected:', data);
});

server.kasflows.on('disconnect', (data) => {
    console.log('Client disconnected:', data);
});

// Start the server
server.start().then(() => {
    console.log('Server successfully started');
});
```

### Using a Client

```javascript
const { Client } = require('kasflowsjs');

const client = new Client('http://localhost:8000');

// Connect to the server
client.connect('my-client-name').then(() => {
    console.log('Connected to server');
    
    // Subscribe to events
    client.on('message', (data) => {
        console.log('Received message:', data);
    });
    
    // Send a message
    client.emit('message', { text: 'Hello from client!' });
    
    // Check for messages from the server
    setInterval(() => {
        client.checkMessages().then(response => {
            if (response.status === 'success') {
                console.log('Received message from server:', response.message);
            }
        });
    }, 1000);
});

// Disconnect from the server
// client.disconnect().then(() => console.log('Disconnected from server'));
```

### Using in Roblox

```lua
local KasflowsClient = require("kasflows")
local client = KasflowsClient.new("http://localhost:8000")

client:connect("roblox-client")

client:on("message", function(data)
    print("Received message:", data)
end)

-- Check for messages from the server
spawn(function()
    while wait(1) do
        local response = client:checkMessages()
        if response.status == "success" then
            print("Received message from server:", response.message)
        end
    end
end)
```

### Configuring Logging

```javascript
const { logger } = require('kasflowsjs');

// Set logging level
logger.setLogLevel(logger.LOG_LEVELS.DEBUG); // DEBUG, INFO, WARN, ERROR

// Use the logger
logger.debug('Debug message');
logger.info('Info message');
logger.warn('Warning message');
logger.error('Error message', { details: 'Additional information' });
```

## API

### KasflowsBase Class

#### on(event, callback)
Subscribe to an event.

#### off(event)
Unsubscribe from an event.

#### emit(event, data)
Emit an event.

### Server Class

#### constructor(host = '127.0.0.1', port = 8000)
Create a new server.

#### start()
Start the server. Returns a Promise.

### Client Class

#### constructor(url)
Create a new client.

#### connect(name)
Connect to the server with the specified name. Returns a Promise.

#### disconnect()
Disconnect from the server. Returns a Promise.

#### on(event, callback)
Subscribe to an event.

#### off(event)
Unsubscribe from an event.

#### emit(event, data)
Send an event to the server. Returns a Promise.

#### checkMessages()
Check for messages from the server. Returns a Promise.

### Logging System

#### logger.setLogLevel(level)
Set the logging level (DEBUG, INFO, WARN, ERROR).

#### logger.debug(message, ...args)
Output a debug message.

#### logger.info(message, ...args)
Output an info message.

#### logger.warn(message, ...args)
Output a warning message.

#### logger.error(message, ...args)
Output an error message.

### Server Endpoints

- `POST /statusws` - Connect and check client status
- `POST /sendmessage` - Send a message
- `POST /getmessage` - Get messages
- `POST /sendmessagetoclient` - Send a message to a specific client
- `POST /disconnect` - Disconnect a client
- `GET /getclients` - Get a list of connected clients

## Advantages

- Full compatibility with the Python version of the library
- Support for event-based model
- Simple API for client and server
- Automatic connection management
- Support for sending messages to specific clients
- Easy integration with Roblox
- Flexible logging system

## Testing

The library includes a set of tests to verify functionality:

```bash
# Start the server for testing
node tests/server.test.js

# In another terminal, run the client
node tests/client.test.js

# Run automated tests (requires Jest)
npm test
```

## License

MIT 