--[[
    KasFlows Client for Roblox
    Version: 1.0.0
    
    Легковесная система коммуникации для Roblox как альтернатива WebSocket
]]

local HttpService = game:GetService("HttpService")
local requestFunc = (syn and syn.request) or (http and http.request) or (request) or (fluxus and fluxus.request)
if not requestFunc then
    error("Ваш режим или среда не поддерживает HTTP запросы")
end

local function httpPost(url, data)
    local response = requestFunc({
        Url = url,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(data)
    })
    return response.Body
end

local function httpGet(url)
    local response = requestFunc({
        Url = url,
        Method = "GET"
    })
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
    self.token = nil
    return self
end

-- Подключение к серверу
function KasflowsClient:connect(name)
    self.name = name
    
    local success, response = pcall(function()
        return httpPost(
            self.url .. "/statusws",
            {name = name}
        )
    end)
    
    if success then
        local data = HttpService:JSONDecode(response)
        if data.status == "connected" or data.status == "already connected" then
            self.connected = true
            self.name = name
            self.token = data.token
            
            self:startPing()
            self:startCheckMessages()
            
            print("KasFlows: Connected to server as " .. name)
            return data
        else
            warn("KasFlows: Failed to connect - " .. data.status)
            return data
        end
    else
        warn("KasFlows: Connection error - " .. response)
        return {status = "error", message = response}
    end
end

-- Отключение от сервера
function KasflowsClient:disconnect()
    if not self.connected then
        return {status = "not connected"}
    end
    
    self:stopPing()
    self:stopCheckMessages()
    
    local success, response = pcall(function()
        return httpPost(
            self.url .. "/disconnect",
            {name = self.name, token = self.token}
        )
    end)
    
    if success then
        local data = HttpService:JSONDecode(response)
        if data.status == "disconnected" then
            self.connected = false
            self.name = nil
            self.token = nil
        end
        print("KasFlows: Disconnected from server")
        return data
    else
        warn("KasFlows: Disconnect error - " .. response)
        return {status = "error", message = response}
    end
end

-- Запуск периодического пинга для поддержания соединения
function KasflowsClient:startPing()
    if self.pingThread then
        self.pingThread:Disconnect()
    end
    
    self.pingThread = spawn(function()
        while self.connected do
            wait(5) -- Пинг каждые 5 секунд
            
            pcall(function()
                httpPost(
                    self.url .. "/statusws",
                    {name = self.name, token = self.token}
                )
            end)
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
            wait(0)
            self:checkMessages()
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
    
    local success, response = pcall(function()
        return httpPost(
            self.url .. "/sendmessage",
            {
                event = event,
                data = data
            }
        )
    end)
    
    if success then
        return HttpService:JSONDecode(response)
    else
        warn("KasFlows: Emit error - " .. response)
        return {status = "error", message = response}
    end
end

-- Проверка наличия сообщений от сервера
function KasflowsClient:checkMessages()
    if not self.connected then
        return {status = "not connected"}
    end
    
    local success, response = pcall(function()
        return httpPost(
            self.url .. "/getmessage",
            {name = self.name, token = self.token}
        )
    end)
    
    if success then
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
    else
        warn("KasFlows: Check messages error - " .. response)
        return {status = "error", message = response}
    end
end

-- Получение списка подключенных клиентов
function KasflowsClient:getClients()
    local success, response = pcall(function()
        return httpGet(self.url .. "/getclients")
    end)
    
    if success then
        return HttpService:JSONDecode(response)
    else
        warn("KasFlows: Get clients error - " .. response)
        return {status = "error", message = response}
    end
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
    
    local success, response = pcall(function()
        return httpPost(
            self.url .. "/sendmessagetoclient",
            payload
        )
    end)
    
    if success then
        return HttpService:JSONDecode(response)
    else
        warn("KasFlows: Send to client error - " .. response)
        return {status = "error", message = response}
    end
end

return KasflowsClient