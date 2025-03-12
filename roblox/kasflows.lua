--[[
    KasFlows Client for Roblox
    Version: 1.1.0
    
    Легковесная система коммуникации для Roblox как альтернатива WebSocket
]]

local HttpService = game:GetService("HttpService")
local requestFunc = (syn and syn.request) or (http and http.request) or (request) or (fluxus and fluxus.request)
if not requestFunc then
    error("Ваш режим или среда не поддерживает HTTP запросы")
end

local function httpPost(url, data)
    local success, response = pcall(function()
        return requestFunc({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
    
    if not success then
        return nil, "Ошибка HTTP запроса: " .. tostring(response)
    end
    
    if response.StatusCode >= 400 then
        return nil, "HTTP ошибка: " .. response.StatusCode .. " - " .. (response.Body or "Нет тела ответа")
    end
    
    return response.Body
end

local function httpGet(url)
    local success, response = pcall(function()
        return requestFunc({
            Url = url,
            Method = "GET"
        })
    end)
    
    if not success then
        return nil, "Ошибка HTTP запроса: " .. tostring(response)
    end
    
    if response.StatusCode >= 400 then
        return nil, "HTTP ошибка: " .. response.StatusCode .. " - " .. (response.Body or "Нет тела ответа")
    end
    
    return response.Body
end

local KasflowsClient = {}
KasflowsClient.__index = KasflowsClient

-- Создание нового клиента
function KasflowsClient.new(url)
    local self = setmetatable({}, KasflowsClient)
    self.url = url
    self.name = nil
    self.connected = false
    self.eventsCallbacks = {}
    self.pingThread = nil
    self.checkMessagesThread = nil
    self.reconnectThread = nil
    self.token = nil
    self.reconnectAttempts = 0
    self.maxReconnectAttempts = 5
    self.reconnectDelay = 5
    self.autoReconnect = true
    self.lastPingTime = 0
    self.pingTimeout = 5-- секунд
    return self
end

-- Подключение к серверу
function KasflowsClient:connect(name)
    self.name = name
    
    local response, error = httpPost(
        self.url .. "/statusws",
        {name = name}
    )
    
    if not response then
        warn("KasFlows: Connection error - " .. error)
        
        if self.autoReconnect then
            self:scheduleReconnect()
        end
        
        return {status = "error", message = error}
    end
    
    local success, data = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    
    if not success then
        warn("KasFlows: Failed to decode response - " .. data)
        
        if self.autoReconnect then
            self:scheduleReconnect()
        end
        
        return {status = "error", message = "JSON decode error: " .. data}
    end
    
    if data.status == "connected" or data.status == "already connected" then
        self.connected = true
        self.name = name
        self.token = data.token
        self.reconnectAttempts = 0
        
        self:startPing()
        self:startCheckMessages()
        
        print("KasFlows: Connected to server as " .. name)
        if self.eventsCallbacks["connect"] then
            self.eventsCallbacks["connect"]()
        end
        return data
    else
        warn("KasFlows: Failed to connect - " .. data.status)
        
        if self.autoReconnect then
            self:scheduleReconnect()
        end
        
        return data
    end
end

-- Планирование переподключения
function KasflowsClient:scheduleReconnect()
    if self.reconnectThread then
        self.reconnectThread:Disconnect()
        self.reconnectThread = nil
    end
    
    self.reconnectAttempts = self.reconnectAttempts + 1
    
    if self.reconnectAttempts > self.maxReconnectAttempts then
        warn("KasFlows: Max reconnect attempts reached, giving up")
        return
    end
    
    local delay = self.reconnectDelay * math.min(self.reconnectAttempts, 3)
    
    print("KasFlows: Scheduling reconnect attempt " .. self.reconnectAttempts .. " in " .. delay .. " seconds")
    
    self.reconnectThread = spawn(function()
        wait(delay)
        
        if not self.connected then
            print("KasFlows: Attempting to reconnect...")
            self:connect(self.name)
        end
    end)
end

-- Отключение от сервера
function KasflowsClient:disconnect()
    if not self.connected then
        if self.eventsCallbacks["disconnect"] then
            self.eventsCallbacks["disconnect"]()
        end
        return {status = "not connected"}
    end
    
    self:stopPing()
    self:stopCheckMessages()
    
    if self.reconnectThread then
        self.reconnectThread:Disconnect()
        self.reconnectThread = nil
    end
    
    local response, error = httpPost(
        self.url .. "/disconnect",
        {name = self.name, token = self.token}
    )
    
    if not response then
        warn("KasFlows: Disconnect error - " .. error)
        
        -- Даже при ошибке отключения считаем клиент отключенным
        self.connected = false
        self.name = nil
        self.token = nil
        
        if self.eventsCallbacks["disconnect"] then
            self.eventsCallbacks["disconnect"]()
        end
        
        return {status = "error", message = error}
    end
    
    local success, data = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    
    if not success then
        warn("KasFlows: Failed to decode disconnect response - " .. data)
        
        -- Даже при ошибке декодирования считаем клиент отключенным
        self.connected = false
        self.name = nil
        self.token = nil
        
        if self.eventsCallbacks["disconnect"] then
            self.eventsCallbacks["disconnect"]()
        end
        
        return {status = "error", message = "JSON decode error: " .. data}
    end
    
    if data.status == "disconnected" then
        self.connected = false
        self.name = nil
        self.token = nil
    end
    
    print("KasFlows: Disconnected from server")
    
    if self.eventsCallbacks["disconnect"] then
        self.eventsCallbacks["disconnect"]()
    end
    
    return data
end

-- Запуск периодического пинга для поддержания соединения
function KasflowsClient:startPing()
    if self.pingThread then
        self.pingThread:Disconnect()
    end
    
    self.lastPingTime = tick()
    
    self.pingThread = spawn(function()
        while self.connected do
            wait(5) -- Пинг каждые 5 секунд
            
            local success, response = pcall(function()
                return httpPost(
                    self.url .. "/statusws",
                    {name = self.name, token = self.token}
                )
            end)
            
            if success and response then
                self.lastPingTime = tick()
            else
                -- Проверяем, не истек ли таймаут пинга
                if tick() - self.lastPingTime > self.pingTimeout then
                    warn("KasFlows: Ping timeout, connection lost")
                    self.connected = false
                    
                    if self.eventsCallbacks["disconnect"] then
                        self.eventsCallbacks["disconnect"]()
                    end
                    
                    if self.autoReconnect then
                        self:scheduleReconnect()
                    end
                    
                    break
                end
            end
        end
    end)
end

-- Остановка пинга
function KasflowsClient:stopPing()
    if self.pingThread then
        self.pingThread:Disconnect()
        self.pingThread = nil
    end
end

-- Запуск проверки сообщений
function KasflowsClient:startCheckMessages()
    if self.checkMessagesThread then
        self.checkMessagesThread:Disconnect()
    end
    
    self.checkMessagesThread = spawn(function()
        while self.connected do
            wait(0.5) -- Проверяем сообщения каждые 0.5 секунд
            
            local success, result = pcall(function()
                return self:checkMessages()
            end)
            
            if not success then
                warn("KasFlows: Error checking messages - " .. tostring(result))
            end
        end
    end)
end

-- Остановка проверки сообщений
function KasflowsClient:stopCheckMessages()
    if self.checkMessagesThread then
        self.checkMessagesThread:Disconnect()
        self.checkMessagesThread = nil
    end
end

-- Подписка на событие
function KasflowsClient:on(event, callback)
    self.eventsCallbacks[event] = callback
    return self
end

-- Отписка от события
function KasflowsClient:off(event)
    self.eventsCallbacks[event] = nil
    return self
end

-- Отправка события на сервер
function KasflowsClient:emit(event, data)
    if not self.connected then
        warn("KasFlows: Cannot emit event - not connected")
        return {status = "not connected"}
    end
    
    data = data or {}
    data.token = self.token
    data.sender = self.name
    
    local response, error = httpPost(
        self.url .. "/sendmessage",
        {
            event = event,
            data = data
        }
    )
    
    if not response then
        warn("KasFlows: Emit error - " .. error)
        return {status = "error", message = error}
    end
    
    local success, result = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    
    if not success then
        warn("KasFlows: Failed to decode emit response - " .. result)
        return {status = "error", message = "JSON decode error: " .. result}
    end
    
    return result
end

-- Проверка наличия сообщений от сервера
function KasflowsClient:checkMessages()
    if not self.connected then
        return {status = "not connected"}
    end
    
    local response, error = httpPost(
        self.url .. "/getmessage",
        {name = self.name, token = self.token}
    )
    
    if not response then
        warn("KasFlows: Check messages error - " .. error)
        return {status = "error", message = error}
    end
    
    local decodeSuccess, data = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    
    if not decodeSuccess then
        warn("KasFlows: Failed to decode message - " .. data)
        return {status = "error", message = "JSON decode error: " .. data}
    end
    
    if data.status == "success" and data.message then
        local message = data.message
        if message.event and self.eventsCallbacks[message.event] then
            local callbackSuccess, callbackError = pcall(function()
                self.eventsCallbacks[message.event](message.data)
            end)
            
            if not callbackSuccess then
                warn("KasFlows: Event callback error - " .. callbackError)
                pcall(function()
                    self:emit("errorlua", {
                        error = callbackError
                    })
                end)
            end
        end
    end
    
    return data
end

-- Получение списка подключенных клиентов
function KasflowsClient:getClients()
    local response, error = httpGet(self.url .. "/getclients")
    
    if not response then
        warn("KasFlows: Get clients error - " .. error)
        return {status = "error", message = error}
    end
    
    local success, result = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    
    if not success then
        warn("KasFlows: Failed to decode clients response - " .. result)
        return {status = "error", message = "JSON decode error: " .. result}
    end
    
    return result
end

-- Отправка сообщения конкретному клиенту
function KasflowsClient:sendToClient(clientName, event, data)
    if not self.connected then
        warn("KasFlows: Cannot send to client - not connected")
        return {status = "not connected"}
    end
    
    local payload = {
        name = clientName,
        message = {
            event = event,
            data = data
        },
        token = self.token
    }
    
    local response, error = httpPost(
        self.url .. "/sendmessagetoclient",
        payload
    )
    
    if not response then
        warn("KasFlows: Send to client error - " .. error)
        return {status = "error", message = error}
    end
    
    local success, result = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    
    if not success then
        warn("KasFlows: Failed to decode send to client response - " .. result)
        return {status = "error", message = "JSON decode error: " .. result}
    end
    
    return result
end

-- Установка параметров автоматического переподключения
function KasflowsClient:setReconnectOptions(options)
    options = options or {}
    
    if options.autoReconnect ~= nil then
        self.autoReconnect = options.autoReconnect
    end
    
    if options.maxAttempts and type(options.maxAttempts) == "number" then
        self.maxReconnectAttempts = options.maxAttempts
    end
    
    if options.delay and type(options.delay) == "number" then
        self.reconnectDelay = options.delay
    end
    
    if options.pingTimeout and type(options.pingTimeout) == "number" then
        self.pingTimeout = options.pingTimeout
    end
    
    return self
end

return KasflowsClient