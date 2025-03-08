--[[
    KasFlows Client for Roblox
    Version: 1.0.0
    
    Легковесная система коммуникации для Roblox как альтернатива WebSocket
]]

local HttpService = game:GetService("HttpService")

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
    self.token = nil
    return self
end

-- Подключение к серверу
function KasflowsClient:connect(name)
    self.name = name
    
    local success, response = pcall(function()
        return HttpService:PostAsync(
            self.url .. "/statusws",
            HttpService:JSONEncode({name = name}),
            Enum.HttpContentType.ApplicationJson
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
        return HttpService:PostAsync(
            self.url .. "/disconnect",
            HttpService:JSONEncode({name = self.name, token = self.token}),
            Enum.HttpContentType.ApplicationJson
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
                HttpService:PostAsync(
                    self.url .. "/statusws",
                    HttpService:JSONEncode({name = self.name}),
                    Enum.HttpContentType.ApplicationJson
                )
            end)
        end
    end)
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
    
    data.token = self.token
    
    local success, response = pcall(function()
        return HttpService:PostAsync(
            self.url .. "/sendmessage",
            HttpService:JSONEncode({
                event = event,
                data = data
            }),
            Enum.HttpContentType.ApplicationJson
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
        return HttpService:PostAsync(
            self.url .. "/getmessage",
            HttpService:JSONEncode({name = self.name, token = self.token}),
            Enum.HttpContentType.ApplicationJson
        )
    end)
    
    if success then
        local data = HttpService:JSONDecode(response)
        
        if data.status == "success" and data.message then
            local message = data.message
            if message.event and self.eventsCallbacks[message.event] then
                spawn(function()
                    self.eventsCallbacks[message.event](message.data)
                end)
            end
        end
        
        return data
    else
        warn("KasFlows: Check messages error - " .. response)
        return {status = "error", message = response}
    end
end

-- Автоматическая проверка сообщений
function KasflowsClient:startAutoCheck(interval)
    interval = interval or 1 -- По умолчанию проверяем каждую секунду
    
    spawn(function()
        while self.connected do
            wait(interval)
            self:checkMessages()
        end
    end)
    
    return self
end

-- Получение списка подключенных клиентов
function KasflowsClient:getClients()
    local success, response = pcall(function()
        return HttpService:GetAsync(self.url .. "/getclients")
    end)
    
    if success then
        return HttpService:JSONDecode(response)
    else
        warn("KasFlows: Get clients error - " .. response)
        return {status = "error", message = response}
    end
end

-- Отправка сообщения конкретному клиенту
function KasflowsClient:sendToClient(clientName, message)
    if not self.connected then
        warn("KasFlows: Cannot send to client - not connected")
        return {status = "not connected"}
    end
    
    local payload = {
        name = clientName,
        message = message
    }
    
    local success, response = pcall(function()
        return HttpService:PostAsync(
            self.url .. "/sendmessagetoclient",
            HttpService:JSONEncode(payload),
            Enum.HttpContentType.ApplicationJson
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
