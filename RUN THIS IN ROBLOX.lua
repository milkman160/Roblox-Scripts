if shared.runBind == nil then
    shared.runBind = Enum.KeyCode.B;
end

if shared.espColor == nil then
    shared.espColor = Color3.new(0, 1, 0.164705)
end

if shared.fillTransparency == nil then
    shared.fillTransparency = 0.2
end

if shared.outlineColor == nil then
    shared.outlineColor = Color3.new(255, 255, 255)
end

if shared.outlineTransparency == nil then
    shared.outlineTransparency = .5
end

local running = false

local HttpService = game:GetService("HttpService")
local plr = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")
local ESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/Sw1ndlerScripts/RobloxScripts/main/Esp%20Library/main.lua",true))()
local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source'))()

local Window = Rayfield:CreateWindow({
    Name = "Chess Script",
    LoadingTitle = "Loading Chess Script",
    LoadingSubtitle = "By Haloxx"
 })

local MainTab = Window:CreateTab("Main", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

local Label = MainTab:CreateLabel("Status: Idle")

local pieces = {
    ["Pawn"] = "p",
    ["Knight"] = "n",
    ["Bishop"] = "b",
    ["Rook"] = "r",
    ["Queen"] = "q",
    ["King"] = "k"
}

if game:GetService("ReplicatedStorage").Connections:FindFirstChild("ReportClientError") then
    game:GetService("ReplicatedStorage").Connections.ReportClientError:Destroy()
    for _,v in pairs(getconnections(game:GetService("ScriptContext").Error)) do
        v:Disable()
    end
end

local client = nil
for _,v in pairs(getreg()) do
    if type(v) == "function" then
        for _, v in pairs(getupvalues(v)) do
            if type(v) == "table" and v.processRound then
                client = v
            end
        end
    end
end
assert(client, "failed to find client")


-- Board from client
function getBoard()
    for _,v in pairs(debug.getupvalues(client.processRound)) do
        if type(v) == "table" and v.tiles then
            return v
        end
    end

    return nil
end

-- Gets client's team (white/black)
function getLocalTeam(board)
    -- Bot match detection
    if board.players[false] == plr and board.players[true] == plr then
        return "w"
    end
    
    for i, v in pairs(board.players) do
        if v == plr then
            -- If the index is true, they are white
            if i then
                return "w"
            else
                return "b"
            end
        end
    end

    return nil
end

function willCauseDesync(board)
    -- Bot match detection
    local state, message = pcall(function()
        if board.players[false] == plr and board.players[true] == plr then
            return board.activeTeam == false
        end
    end)

    if not state then
        return false
    end

    for i,v in pairs(board.players) do
        if v == plr then
            -- If the index is true, they are white
            return not (board.activeTeam == i)
        end
    end

    return true
end

-- Converts awful format of board table to a sensible one
function createBoard(board)
    local newBoard = {}
    for _,v in pairs(board.whitePieces) do
        if v and v.position then
            local x, y = v.position[1], v.position[2]
            if not newBoard[x] then
                newBoard[x] = {}
            end
            newBoard[x][y] = string.upper(pieces[v.object.Name])
        end
    end
    for _,v in pairs(board.blackPieces) do
        if v and v.position then
            local x, y = v.position[1], v.position[2]
            if not newBoard[x] then
                newBoard[x] = {}
            end
            newBoard[x][y] = pieces[v.object.Name]
        end
    end

    return newBoard
end

-- Board to FEN encoding
function board2fen(board)
    local result = ""
    local boardPieces = createBoard(board)
    for y = 8, 1, -1 do
        local empty = 0
        for x = 8, 1, -1 do
            if not boardPieces[x] then boardPieces[x] = {} end
            local piece = boardPieces[x][y]
            if piece then
                if empty > 0 then
                    result = result .. tostring(empty)
                    empty = 0
                end
                result = result .. piece
            else
                empty += 1
            end
        end
        if empty > 0 then
            result = result .. tostring(empty)
        end
        if not (y == 1) then
            result = result .. "/"
        end
    end
    result = result .. " " .. getLocalTeam(board)
    return result
end

function getPiece(tile)
    local rayOrigin
    local boardTile = game:GetService("Workspace").Board[tile]

    if boardTile.ClassName == 'Model' then
        if game:GetService("Workspace").Board[tile]:FindFirstChild('Meshes/tile_a') then
            rayOrigin = game:GetService("Workspace").Board[tile]['Meshes/tile_a'].Position
        else
            rayOrigin = game:GetService("Workspace").Board[tile]['Tile'].Position
        end
    else
        rayOrigin = game:GetService("Workspace").Board[tile].Position
    end
    
    local rayDirection = Vector3.new(0, 10, 0)
    
    local raycastResult = workspace:Raycast(rayOrigin, rayDirection)
    
    if raycastResult ~= nil then
        return raycastResult.Instance.Parent
    end

    return nil
end

function gameInProgress()
    return #game:GetService("Workspace").Board:GetChildren() > 0
end

function playerIsWhite()
    if string.match(plr.PlayerGui.GameStatus.White.Info.Text, plr.DisplayName) then
        return true
    end
    return false
end

function runGame()
    -- Get chess board
    local board = getBoard()
    
    -- Check if we're able to run without desync
    if not willCauseDesync(board) then
        Label:Set("Status: Error!")
        return false
    end

    local result = game:HttpGet("http://localhost:3000/api/solve?fen=" .. HttpService:UrlEncode(board2fen(board)))

    -- Ensure result is valid
    if string.len(result) > 5 then
        Label:Set("Status: Error!")
        error(result)
    end

    -- Extrapolate movement from result string
    local chars = {}
    for c in result:gmatch(".") do
        table.insert(chars, c)
    end

    -- Get move positions from table
    local x1 = 9 - (string.byte(chars[1]) - 96)
    local y1 = tonumber(chars[2])
    
    local x2 = 9 - (string.byte(chars[3]) - 96)
    local y2 = tonumber(chars[4])

    local pieceToMove = getPiece(x1 .. "," .. y1)
    local placeToMove = game:GetService("Workspace").Board[x2 .. "," .. y2]


    ESP:addHighlight(pieceToMove, {
        FillColor = shared.espColor,
        FillTransparency = shared.fillTransparency,
        OutlineColor = Color3.new(255, 255, 255),
        OutlineTransparency = 0.5
    })
    
    ESP:addHighlight(placeToMove, {
        FillColor = shared.espColor,
        FillTransparency = shared.fillTransparency,
        OutlineColor = Color3.new(255, 255, 255),
        OutlineTransparency = 0.5
    })

    Label:Set("Status: Done!")

    if playerIsWhite() then
        repeat
            task.wait()
        until plr.PlayerGui.GameStatus.White.Visible == false or gameInProgress() == false
        ESP:clearEsp()
    else
        repeat
            task.wait()
        until plr.PlayerGui.GameStatus.Black.Visible == false or gameInProgress() == false
        ESP:clearEsp()
    end
    return true
end

local ColorPicker
local FillTransparencySlider
local ColorPicker2
local OutlineTransparencySlider2
local Keybind

local ResetAllValuesButton = MainTab:CreateButton({
    Name = "Reset All Settings",
    Callback = function()
        shared.fillTransparency = 0.2
        shared.espColor = Color3.new(0, 1, 0.164705)
        shared.runBind = Enum.KeyCode.B;
        shared.outlineColor = Color3.new(255, 255, 255)
        shared.outlineTransparency = .5

        ColorPicker:Set(Color3.new(0, 1, 0.164705))
        FillTransparencySlider:Set(.2)

        ColorPicker2:Set(Color3.new(255, 255, 255))
        OutlineTransparencySlider2:Set(.5)

        Keybind:Set("B")
    end,
})

Keybind = MainTab:CreateKeybind({
    Name = "Run Stockfish Bind",
    CurrentKeybind = UIS:GetStringForKeyCode(shared.runBind),
    HoldToInteract = false,
    Flag = "Keybind1",
    Callback = function(keybind)
        if not running then
            running = true
            Label:Set("Status: Calculating")
            if runGame() then
                print("Ran AI")
            else
                print("Cannot run AI right now")
                Label:Set("Status: Error!")
                task.wait(.5)
            end
            Label:Set("Status: Idle")
            running = false
        end
    end,
})

ColorPicker = MainTab:CreateColorPicker({
    Name = "Change ESP Color",
    Color = shared.espColor,
    Flag = "ColorPicker1",
    Callback = function(value)
        shared.espColor = value
    end
})

FillTransparencySlider = MainTab:CreateSlider({
    Name = "Fill Transparency",
    Range = {0, 1},
    Increment = .1,
    Suffix = "",
    CurrentValue = shared.fillTransparency,
    Flag = "Slider1",
    Callback = function(value)
        shared.fillTransparency = value
    end,
})

MainTab:CreateLabel("")

ColorPicker2 = MainTab:CreateColorPicker({
    Name = "Change Outline Color",
    Color = shared.outlineColor,
    Flag = "ColorPicker2",
    Callback = function(value)
        shared.outlineColor = value
    end
})

OutlineTransparencySlider2 = MainTab:CreateSlider({
    Name = "Outline Transparency",
    Range = {0, 1},
    Increment = .1,
    Suffix = "",
    CurrentValue = shared.outlineTransparency,
    Flag = "Slider2",
    Callback = function(value)
        shared.outlineTransparency = value
    end,
})

local DestoryUIButton = SettingsTab:CreateButton({
    Name = "Fully Destory UI",
    Callback = function()
        Rayfield:Destroy()
    end,
})

task.spawn(function()
    while task.wait() do
        shared.runBind = Enum.KeyCode[Keybind.CurrentKeybind]
    end
end)

print('executed')
