-- Пример использования KasFlows в Roblox

local KasflowsClient = require(script.Parent.kasflows)

-- Создаем клиент
local client = KasflowsClient.new("http://localhost:8000")

-- Подключаемся к серверу
local connection = client:connect("roblox-game-" .. game.JobId)

-- Обработка событий от сервера
client:on("message", function(data)
    print("Получено сообщение:", HttpService:JSONEncode(data))
    
    -- Пример ответа на сообщение
    client:emit("response", {
        received = true,
        timestamp = os.time()
    })
end)

-- Обработка события обновления игры
client:on("gameUpdate", function(data)
    if data.type == "announcement" then
        -- Показать объявление всем игрокам
        for _, player in pairs(game.Players:GetPlayers()) do
            game.ReplicatedStorage.Events.ShowAnnouncement:FireClient(player, data.message)
        end
    elseif data.type == "restart" then
        -- Логика перезапуска сервера
        print("Получена команда перезапуска сервера")
    end
end)

-- Отправка информации о сервере
client:emit("serverInfo", {
    placeId = game.PlaceId,
    jobId = game.JobId,
    playerCount = #game.Players:GetPlayers(),
    maxPlayers = game.Players.MaxPlayers,
    serverStartTime = os.time()
})

-- Автоматическая проверка сообщений каждые 2 секунды
client:startAutoCheck(2)

-- Отправка статистики каждые 30 секунд
spawn(function()
    while wait(30) do
        if client.connected then
            client:emit("stats", {
                playerCount = #game.Players:GetPlayers(),
                uptime = os.time() - game:GetService("Stats").ServerStatsItem["Start Time"]:GetValue(),
                memory = game:GetService("Stats").ServerStatsItem["Memory (KB)"]:GetValue(),
                ping = game:GetService("Stats").ServerStatsItem["Data Ping"]:GetValue()
            })
        end
    end
end)

-- Обработка отключения игрока
game.Players.PlayerRemoving:Connect(function(player)
    if client.connected then
        client:emit("playerLeft", {
            username = player.Name,
            userId = player.UserId
        })
    end
end)

-- Обработка подключения игрока
game.Players.PlayerAdded:Connect(function(player)
    if client.connected then
        client:emit("playerJoined", {
            username = player.Name,
            userId = player.UserId,
            timestamp = os.time()
        })
    end
end)

-- Отключение при закрытии сервера
game:BindToClose(function()
    if client.connected then
        client:emit("serverClosing", {
            placeId = game.PlaceId,
            jobId = game.JobId,
            reason = "normal"
        })
        client:disconnect()
    end
end) 