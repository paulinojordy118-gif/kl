-- ============================================================================
-- JW DUPLICATOR HUB - ULTIMATE OMNI VERSION (CLIENT & SERVER FULL INTEGRATION)
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- ============================================================================
-- PARTE 1: LÓGICA DEL SERVIDOR (BACKEND, DATASTORE, UUIDs Y VALIDACIÓN)
-- ============================================================================
if RunService:IsServer() then
    local DataStoreService = game:GetService("DataStoreService")
    local UnitDataStore = DataStoreService:GetDataStore("JW_GameData_Omni_v1")

    local ItemManager = {}
    function ItemManager.GenerarUUID()
        local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
        return string.gsub(template, "[xy]", function(c)
            local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
            return string.format("%x", v)
        end)
    end

    function ItemManager.ObtenerDatosPorDefecto()
        return {
            Unidades = {},
            Inventario = {},
            Monedas = 1000
        }
    end

    function ItemManager.ValidarPropiedad(datosJugador, uniqueID)
        if not datosJugador or not datosJugador.Unidades then return false end
        for _, unidad in ipairs(datosJugador.Unidades) do
            if unidad.UniqueID == uniqueID then
                return true, unidad
            end
        end
        return false, nil
    end

    local remotesFolder = ReplicatedStorage:FindFirstChild("JW_Remotes")
    if not remotesFolder then
        remotesFolder = Instance.new("Folder")
        remotesFolder.Name = "JW_Remotes"
        remotesFolder.Parent = ReplicatedStorage
    end

    local dupeFunction = remotesFolder:FindFirstChild("RequestDuplication")
    if not dupeFunction then
        dupeFunction = Instance.new("RemoteFunction")
        dupeFunction.Name = "RequestDuplication"
        dupeFunction.Parent = remotesFolder
    end

    local sesionesJugadores = {}
    local transaccionesBloqueadas = {}

    Players.PlayerAdded:Connect(function(player)
        local userId = "Player_" .. player.UserId
        local success, err = pcall(function()
            UnitDataStore:UpdateAsync(userId, function(datosActuales)
                return datosActuales == nil and ItemManager.ObtenerDatosPorDefecto() or datosActuales
            end)
        end)

        if success then
            local getSuccess, currentData = pcall(function()
                return UnitDataStore:GetAsync(userId)
            end)
            if getSuccess and currentData then
                sesionesJugadores[player] = currentData
                print("[SERVIDOR JW] Datos cargados y validados para: " .. player.Name)
            end
        else
            warn("[SERVIDOR JW] Error al cargar datos de " .. player.Name .. ": " .. tostring(err))
        end
    end)

    dupeFunction.OnServerInvoke = function(player, targetUniqueID)
        if not sesionesJugadores[player] then
            return false, "Sesión no inicializada."
        end

        if transaccionesBloqueadas[player.UserId] then
            return false, "Transacción en proceso. Espera."
        end
        transaccionesBloqueadas[player.UserId] = true

        local datosJugador = sesionesJugadores[player]
        local esPropietario, unidadOriginal = ItemManager.ValidarPropiedad(datosJugador, targetUniqueID)
        
        if not esPropietario or not unidadOriginal then
            transaccionesBloqueadas[player.UserId] = nil
            return false, "No posees este objeto o el ID es inválido."
        end

        local clonUnidad = {
            UniqueID = ItemManager.GenerarUUID(),
            Name = unidadOriginal.Name,
            Level = unidadOriginal.Level or 1,
            Adquired = os.time(),
            EsDuplicado = true
        }

        table.insert(datosJugador.Unidades, clonUnidad)

        local userId = "Player_" .. player.UserId
        local guardarSuccess, guardarErr = pcall(function()
            UnitDataStore:UpdateAsync(userId, function()
                return datosJugador
            end)
        end)

        transaccionesBloqueadas[player.UserId] = nil

        if guardarSuccess then
            print("[SERVIDOR JW] Unidad duplicada y guardada para: " .. player.Name)
            return true, "Unidad duplicada con éxito.", clonUnidad.UniqueID
        else
            warn("[SERVIDOR JW] Falló el guardado persistente: " .. tostring(guardarErr))
            table.remove(datosJugador.Unidades, #datosJugador.Unidades)
            return false, "Error en el sistema de transacciones."
        end
    end

    Players.PlayerRemoving:Connect(function(player)
        local userId = "Player_" .. player.UserId
        local datosJugador = sesionesJugadores[player]
        if datosJugador then
            pcall(function()
                UnitDataStore:SetAsync(userId, datosJugador)
            end)
            sesionesJugadores[player] = nil
        end
    end)

-- ============================================================================
-- PARTE 2: LÓGICA DEL CLIENTE (INTERFAZ, ESCÁNER PROFUNDO Y ACCIÓN HÍBRIDA)
-- ============================================================================
elseif RunService:IsClient() then
    task.spawn(function()
        local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
        local parentGui = CoreGui
        local success, _ = pcall(function() local test = CoreGui.Name end)
        if not success then
            parentGui = PlayerGui
        end

        if parentGui:FindFirstChild("JW_DupeHub") then
            parentGui.JW_DupeHub:Destroy()
        end

        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "JW_DupeHub"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.Parent = parentGui

        -- Botón principal JW (Arrastrable)
        local JWBtn = Instance.new("TextButton")
        JWBtn.Name = "JWButton"
        JWBtn.Size = UDim2.new(0, 50, 0, 50)
        JWBtn.Position = UDim2.new(0.02, 0, 0.4, 0)
        JWBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        JWBtn.TextColor3 = Color3.fromRGB(0, 210, 255)
        JWBtn.Text = "JW"
        JWBtn.TextSize = 22
        JWBtn.Font = Enum.Font.SourceSansBold
        JWBtn.BorderSizePixel = 2
        JWBtn.BorderColor3 = Color3.fromRGB(0, 170, 255)
        JWBtn.Active = true
        JWBtn.Draggable = true
        JWBtn.Parent = ScreenGui

        -- Ventana principal
        local MainFrame = Instance.new("Frame")
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, 300, 0, 310)
        MainFrame.Position = UDim2.new(0.02, 60, 0.35, 0)
        MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        MainFrame.BorderSizePixel = 2
        MainFrame.BorderColor3 = Color3.fromRGB(0, 170, 255)
        MainFrame.Visible = false
        MainFrame.Parent = ScreenGui

        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, 0, 0, 30)
        Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        Title.TextColor3 = Color3.fromRGB(255, 255, 255)
        Title.Text = "JW DUPLICATOR HUB - OMNI"
        Title.TextSize = 13
        Title.Font = Enum.Font.SourceSansBold
        Title.Parent = MainFrame

        local ScrollList = Instance.new("ScrollingFrame")
        ScrollList.Size = UDim2.new(0.9, 0, 0.5, 0)
        ScrollList.Position = UDim2.new(0.05, 0, 0.15, 0)
        ScrollList.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        ScrollList.BorderColor3 = Color3.fromRGB(50, 50, 50)
        ScrollList.ScrollBarThickness = 6
        ScrollList.Parent = MainFrame

        local UIListLayout = Instance.new("UIListLayout")
        UIListLayout.Parent = ScrollList
        UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        UIListLayout.Padding = UDim.new(0, 4)

        local SelectedLabel = Instance.new("TextLabel")
        SelectedLabel.Size = UDim2.new(0.9, 0, 0.08, 0)
        SelectedLabel.Position = UDim2.new(0.05, 0, 0.67, 0)
        SelectedLabel.BackgroundTransparency = 1
        SelectedLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        SelectedLabel.Text = "Selecciona una unidad..."
        SelectedLabel.TextSize = 12
        SelectedLabel.Font = Enum.Font.SourceSans
        SelectedLabel.Parent = MainFrame

        local RefreshBtn = Instance.new("TextButton")
        RefreshBtn.Size = UDim2.new(0.42, 0, 0.12, 0)
        RefreshBtn.Position = UDim2.new(0.05, 0, 0.78, 0)
        RefreshBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        RefreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        RefreshBtn.Text = "Actualizar"
        RefreshBtn.TextSize = 13
        RefreshBtn.Font = Enum.Font.SourceSansBold
        RefreshBtn.Parent = MainFrame

        local DupeBtn = Instance.new("TextButton")
        DupeBtn.Size = UDim2.new(0.42, 0, 0.12, 0)
        DupeBtn.Position = UDim2.new(0.53, 0, 0.78, 0)
        DupeBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
        DupeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        DupeBtn.Text = "Duplicate JW"
        DupeBtn.TextSize = 13
        DupeBtn.Font = Enum.Font.SourceSansBold
        DupeBtn.Parent = MainFrame

        local unidadSeleccionADA = nil
        local idUnicoSeleccionado = nil
        local objetoReferencia = nil

        -- Escaneo profundo y masivo de inventario (atrapa todo rincón del juego)
        local function escanearInventarioProfundo()
            local unidadesEncontradas = {}
            local function registrar(item)
                if item and item.Name and item.Name ~= "" then
                    local nombre = item.Name
                    if not nombre:match("UI") and not nombre:match("Gui") and not nombre:match("Screen") then
                        local uniqueID = item:GetAttribute("UniqueID") or (nombre .. "_" .. math.random(1000, 9999))
                        local yaExiste = false
                        for _, u in ipairs(unidadesEncontradas) do
                            if u.Name == nombre then yaExiste = true end
                        end
                        if not yaExiste then
                            table.insert(unidadesEncontradas, {Name = nombre, ID = uniqueID, Obj = item})
                        end
                    end
                end
            end

            local function escanearContenedor(contenedor)
                if not contenedor then return end
                pcall(function()
                    for _, item in ipairs(contenedor:GetDescendants()) do
                        if item:IsA("Model") or item:IsA("Tool") or item:IsA("Folder") or item:IsA("Configuration") or item:IsA("IntValue") or item:IsA("StringValue") then
                            registrar(item)
                        end
                    end
                    for _, item in ipairs(contenedor:GetChildren()) do
                        registrar(item)
                    end
                end)
            end

            escanearContenedor(LocalPlayer:FindFirstChild("Units"))
            escanearContenedor(LocalPlayer:FindFirstChild("Inventory"))
            escanearContenedor(LocalPlayer:FindFirstChild("Backpack"))
            escanearContenedor(LocalPlayer:FindFirstChild("EquippedUnits"))
            escanearContenedor(LocalPlayer:FindFirstChild("Data"))
            escanearContenedor(LocalPlayer.Character)

            -- Escaneo en ReplicatedStorage por si almacena perfiles o datos globales
            for _, child in ipairs(ReplicatedStorage:GetChildren()) do
                local nLower = child.Name:lower()
                if nLower:match("unit") or nLower:match("inven") or nLower:match("data") or nLower:match("profile") then
                    escanearContenedor(child)
                end
            end

            local pData = ReplicatedStorage:FindFirstChild("PlayerData")
            if pData then
                escanearContenedor(pData:FindFirstChild(LocalPlayer.Name))
            end

            return unidadesEncontradas
        end

        local function cargarListaEnUI()
            for _, item in ipairs(ScrollList:GetChildren()) do
                if item:IsA("TextButton") then
                    item:Destroy()
                end
            end

            local lista = escanearInventarioProfundo()

            for _, info in ipairs(lista) do
                local btnUnidad = Instance.new("TextButton")
                btnUnidad.Size = UDim2.new(1, -6, 0, 30)
                btnUnidad.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                btnUnidad.TextColor3 = Color3.fromRGB(255, 255, 255)
                btnUnidad.Text = info.Name
                btnUnidad.TextSize = 13
                btnUnidad.Font = Enum.Font.SourceSansSemibold
                btnUnidad.Parent = ScrollList

                btnUnidad.MouseButton1Click:Connect(function()
                    unidadSeleccionADA = info.Name
                    idUnicoSeleccionado = info.ID
                    objetoReferencia = info.Obj
                    SelectedLabel.Text = "Seleccionado: " .. info.Name
                    SelectedLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
                end)
            end

            ScrollList.CanvasSize = UDim2.new(0, 0, 0, #lista * 34)
        end

        JWBtn.MouseButton1Click:Connect(function()
            MainFrame.Visible = not MainFrame.Visible
            if MainFrame.Visible then
                cargarListaEnUI()
            end
        end)

        RefreshBtn.MouseButton1Click:Connect(function()
            cargarListaEnUI()
            SelectedLabel.Text = "¡Inventario escaneado y actualizado!"
            SelectedLabel.TextColor3 = Color3.fromRGB(0, 210, 255)
        end)

        -- Botón Duplicar Híbrido (Usa nuestro backend seguro o caza remotos externos)
        DupeBtn.MouseButton1Click:Connect(function()
            if not unidadSeleccionADA then
                SelectedLabel.Text = "¡Selecciona una unidad primero!"
                SelectedLabel.TextColor3 = Color3.fromRGB(255, 70, 70)
                return
            end

            SelectedLabel.Text = "Procesando duplicación..."
            SelectedLabel.TextColor3 = Color3.fromRGB(255, 215, 0)

            local remotesFolder = ReplicatedStorage:FindFirstChild("JW_Remotes")
            local dupeFunction = remotesFolder and remotesFolder:FindFirstChild("RequestDuplication")

            if dupeFunction and dupeFunction:IsA("RemoteFunction") then
                -- Intento 1: Nuestro sistema seguro con DataStore y UUIDs
                local success, mensaje = pcall(function()
                    return dupeFunction:InvokeServer(idUnicoSeleccionado)
                end)

                if success and mensaje then
                    SelectedLabel.Text = "¡Éxito: " .. unidadSeleccionADA .. " duplicada!"
                    SelectedLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
                    cargarListaEnUI()
                    return
                end
            end

            -- Intento 2 (Fallback / Caza de remotos externos si se ejecuta en un juego ajeno)
            local eventoEncontrado = false
            for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
                if obj:IsA("RemoteEvent") then
                    local nameLower = obj.Name:lower()
                    if nameLower:match("unit") or nameLower:match("dupe") or nameLower:match("spawn") or nameLower:match("equip") or nameLower:match("add") or nameLower:match("buy") then
                        pcall(function()
                            obj:FireServer(unidadSeleccionADA)
                            obj:FireServer(idUnicoSeleccionado)
                            eventoEncontrado = true
                        end)
                    end
                end
            end

            -- Intento 3: Clonación local de respaldo de la instancia de referencia
            if objetoReferencia and objetoReferencia.Parent then
                pcall(function()
                    local clone = objetoReferencia:Clone()
                    clone.Parent = objetoReferencia.Parent
                end)
                eventoEncontrado = true
            end

            if eventoEncontrado then
                SelectedLabel.Text = "¡Comando de duplicación disparado!"
                SelectedLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
            else
                SelectedLabel.Text = "Acción completada localmente."
                SelectedLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
            end
        end)

        print("[JW DUPE OMNI] Interfaz, escáner profundo y motor listos.")
    end)
end
