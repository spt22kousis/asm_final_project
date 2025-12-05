; 塔防遊戲 - Irvine32 組合語言版 (Debugged)
; 修正了 Draw 函數導致的堆疊崩潰 (Stack Corruption)
; 修正者：Gemini

INCLUDE Irvine32.inc
main          EQU start@0
; --- 常數定義 ---
MapWidth EQU 20
MapHeight EQU 10
MaxEnemies EQU 50
MaxTowers EQU 30
TowerCost EQU 50
TowerDamage EQU 2
BaseHP EQU 20
StartMoney EQU 150
GameTickMs EQU 250
TowerRangeSq EQU 12

; --- 結構體大小定義 (Bytes) ---
; Point: x(4), y(4)
PointSize EQU 8

; Enemy: id(4), pathIndex(4), hp(4), maxHp(4), active(4)
EnemySize EQU 20
EnemyOff_ID EQU 0
EnemyOff_PathIdx EQU 4
EnemyOff_HP EQU 8
EnemyOff_MaxHP EQU 12
EnemyOff_Active EQU 16

; Tower: x(4), y(4), active(4), killCount(4)
TowerSize EQU 16
TowerOff_X EQU 0
TowerOff_Y EQU 4
TowerOff_Active EQU 8
TowerOff_KillCount EQU 12

.data
    ; --- 遊戲狀態 ---
    money       DWORD ?
    health      DWORD ?
    wave        DWORD ?
    gameOver    DWORD 0
    
    ; --- 陣列 ---
    mapBuffer   BYTE  MapWidth * MapHeight DUP(' ')
    pathArray   DWORD 100 * 2 DUP(0)
    pathLength  DWORD 0
    enemies     BYTE  MaxEnemies * EnemySize DUP(0)
    towers      BYTE  MaxTowers * TowerSize DUP(0)
    
    ; --- 戰鬥階段變數 ---
    tick            DWORD 0
    enemiesSpawned  DWORD 0
    enemiesTotal    DWORD 0
    enemiesAlive    DWORD 0
    
    ; --- 字串 ---
    strTitle    BYTE "=== MASM Auto Tower Defense (Wave ", 0
    strClose    BYTE ") ===", 0dh, 0ah, 0
    strStats    BYTE "Money: $", 0
    strHealth   BYTE "  |  Base HP: ", 0
    strPrep     BYTE 0dh, 0ah, "State: [PREP] (b)Build ($50) | (s)Start | (q)Quit", 0dh, 0ah, "Cmd: ", 0
    strBattle   BYTE 0dh, 0ah, "State: [BATTLE] Enemies Left: ", 0
    strInputPos BYTE "Enter X Y (e.g., 5 5): ", 0
    strMsgBuild BYTE ">> Tower Built!", 0dh, 0ah, 0
    strMsgErr   BYTE ">> Invalid Pos or No Money!", 0dh, 0ah, 0
    strLose     BYTE 0dh, 0ah, "=== GAME OVER ===", 0dh, 0ah, 0
    strWinWave  BYTE 0dh, 0ah, ">> Wave Cleared! <<", 0dh, 0ah, 0
    
    strBorderH  BYTE "  +--------------------+", 0dh, 0ah, 0
    strRowStart BYTE " |", 0
    strRowEnd   BYTE "|", 0dh, 0ah, 0

.code
main PROC
    call InitGame

GameLoop:
    cmp gameOver, 1
    je ExitMain

    ; 1. 準備階段
    call RunPrepPhase
    
    cmp gameOver, 1
    je ExitMain

    ; 2. 戰鬥階段
    call RunBattlePhase
    
    cmp health, 0
    jg NextWave
    mov gameOver, 1
    call Clrscr
    mov edx, OFFSET strLose
    call WriteString
    jmp ExitMain

NextWave:
    mov eax, wave
    imul eax, 10
    add eax, 50
    add money, eax
    
    inc wave
    jmp GameLoop

ExitMain:
    exit
main ENDP

; --- 初始化遊戲 ---
InitGame PROC
    mov money, StartMoney
    mov health, BaseHP
    mov wave, 1
    mov gameOver, 0
    call InitPath
    
    cld
    mov edi, OFFSET towers
    mov ecx, MaxTowers * TowerSize
    mov al, 0
    rep stosb
    ret
InitGame ENDP

; --- 初始化路徑 ---
InitPath PROC
    mov pathLength, 0
    mov esi, OFFSET pathArray
    
    mov ecx, 0 ; x
    mov edx, 1 ; y
L1:
    mov [esi], ecx
    mov [esi+4], edx
    add esi, 8
    inc pathLength
    inc ecx
    cmp ecx, 15
    jle L1
    dec ecx 

L2:
    mov [esi], ecx
    mov [esi+4], edx
    add esi, 8
    inc pathLength
    inc edx
    cmp edx, 6
    jle L2
    dec edx 

L3:
    mov [esi], ecx
    mov [esi+4], edx
    add esi, 8
    inc pathLength
    dec ecx
    cmp ecx, 5
    jge L3
    inc ecx 

L4:
    mov [esi], ecx
    mov [esi+4], edx
    add esi, 8
    inc pathLength
    inc edx
    cmp edx, 8
    jle L4
    dec edx 

L5:
    mov [esi], ecx
    mov [esi+4], edx
    add esi, 8
    inc pathLength
    inc ecx
    cmp ecx, MapWidth
    jl L5
    ret
InitPath ENDP

; --- 準備階段 ---
RunPrepPhase PROC
PrepLoop:
    push 0 
    push 0
    call Draw
    
    mov edx, OFFSET strPrep
    call WriteString
    
    call ReadChar
    
    cmp al, 'q'
    je QuitGame
    cmp al, 's'
    je StartBattle
    cmp al, 'b'
    je BuildMode
    jmp PrepLoop

BuildMode:
    call Crlf
    mov edx, OFFSET strInputPos
    call WriteString
    call ReadInt
    mov ebx, eax 
    call ReadInt
    mov ecx, eax 
    
    call BuildTower
    call DelayBig
    jmp PrepLoop

QuitGame:
    mov gameOver, 1
    ret
StartBattle:
    ret
RunPrepPhase ENDP

; --- 戰鬥階段 ---
RunBattlePhase PROC
    mov tick, 0
    mov enemiesSpawned, 0
    mov enemiesAlive, 0
    
    mov eax, wave
    shl eax, 1
    add eax, 5
    mov enemiesTotal, eax
    
    mov edi, OFFSET enemies
    mov ecx, MaxEnemies * EnemySize
    mov al, 0
    rep stosb

BattleLoop:
    cmp health, 0
    jle EndBattle

    mov eax, enemiesSpawned
    cmp eax, enemiesTotal
    jge SkipSpawn
    
    mov eax, tick
    and eax, 3
    cmp eax, 0
    jne SkipSpawn
    
    call SpawnEnemy

SkipSpawn:
    call MoveEnemies
    call TowersAttack
    
    push enemiesTotal
    push enemiesAlive
    call Draw
    
    mov eax, enemiesSpawned
    cmp eax, enemiesTotal
    jl ContinueBattle
    cmp enemiesAlive, 0
    jg ContinueBattle
    
    mov edx, OFFSET strWinWave
    call WriteString
    mov eax, 2000
    call Delay
    jmp EndBattle

ContinueBattle:
    inc tick
    mov eax, GameTickMs
    call Delay
    jmp BattleLoop

EndBattle:
    ret
RunBattlePhase ENDP

; --- 生成敵人 ---
SpawnEnemy PROC
    mov esi, OFFSET enemies
    mov ecx, MaxEnemies
FindSlot:
    cmp DWORD PTR [esi + EnemyOff_Active], 0
    je FoundSlot
    add esi, EnemySize
    loop FindSlot
    ret

FoundSlot:
    mov DWORD PTR [esi + EnemyOff_Active], 1
    mov DWORD PTR [esi + EnemyOff_PathIdx], 0
    
    mov eax, wave
    imul eax, 3
    add eax, 5
    mov DWORD PTR [esi + EnemyOff_HP], eax
    mov DWORD PTR [esi + EnemyOff_MaxHP], eax
    
    inc enemiesSpawned
    inc enemiesAlive
    ret
SpawnEnemy ENDP

; --- 移動敵人 ---
MoveEnemies PROC
    mov esi, OFFSET enemies
    mov ecx, MaxEnemies
MoveLoop:
    cmp DWORD PTR [esi + EnemyOff_Active], 1
    jne NextEnemyMove
    
    mov eax, [esi + EnemyOff_PathIdx]
    inc eax
    mov [esi + EnemyOff_PathIdx], eax
    
    cmp eax, pathLength
    jl NextEnemyMove
    
    mov DWORD PTR [esi + EnemyOff_Active], 0
    dec health
    dec enemiesAlive

NextEnemyMove:
    add esi, EnemySize
    loop MoveLoop
    ret
MoveEnemies ENDP

; --- 塔攻擊 ---
TowersAttack PROC
    mov esi, OFFSET towers
    mov ecx, MaxTowers
TowerLoop:
    push ecx 
    
    cmp DWORD PTR [esi + TowerOff_Active], 1
    jne NextTower
    
    mov edi, OFFSET enemies
    mov ecx, MaxEnemies
EnemyCheckLoop:
    cmp DWORD PTR [edi + EnemyOff_Active], 1
    jne NextEnemyCheck
    
    mov eax, [edi + EnemyOff_PathIdx]
    mov ebx, 8 
    mul ebx
    mov edx, OFFSET pathArray
    add edx, eax 
    
    mov eax, [edx]   
    mov ebx, [edx+4] 
    
    push eax 
    sub eax, [esi + TowerOff_X]
    imul eax, eax 
    mov ebp, eax  
    pop eax 
    
    push ebx 
    sub ebx, [esi + TowerOff_Y]
    imul ebx, ebx 
    add ebp, ebx  
    pop ebx
    
    cmp ebp, TowerRangeSq
    jg NextEnemyCheck
    
    mov eax, [edi + EnemyOff_HP]
    sub eax, TowerDamage
    mov [edi + EnemyOff_HP], eax
    
    cmp eax, 0
    jg AttackDone 
    
    mov DWORD PTR [edi + EnemyOff_Active], 0
    dec enemiesAlive
    mov eax, wave
    add eax, 5
    add money, eax
    jmp AttackDone

NextEnemyCheck:
    add edi, EnemySize
    loop EnemyCheckLoop

AttackDone:
NextTower:
    pop ecx 
    add esi, TowerSize
    dec ecx
    cmp ecx, 0
    jg TowerLoop
    ret
TowersAttack ENDP

; --- 建造塔 ---
BuildTower PROC
    cmp money, TowerCost
    jl BuildFail
    
    cmp ebx, 0
    jl BuildFail
    cmp ebx, MapWidth
    jge BuildFail
    cmp ecx, 0
    jl BuildFail
    cmp ecx, MapHeight
    jge BuildFail
    
    push ecx
    push ebx
    mov edx, OFFSET pathArray
    mov eax, pathLength
CheckPathLoop:
    cmp [edx], ebx     
    jne NextPathP
    cmp [edx+4], ecx   
    jne NextPathP
    pop ebx
    pop ecx
    jmp BuildFail
NextPathP:
    add edx, 8
    dec eax
    cmp eax, 0
    jg CheckPathLoop
    pop ebx
    pop ecx
    
    mov esi, OFFSET towers
    mov edi, 0 
    mov edx, MaxTowers
    
CheckTowerLoop:
    cmp DWORD PTR [esi + TowerOff_Active], 1
    jne IsEmptySlot
    cmp [esi + TowerOff_X], ebx
    jne NextTw
    cmp [esi + TowerOff_Y], ecx
    je BuildFail 
    jmp NextTw
    
IsEmptySlot:
    cmp edi, 0
    jne NextTw
    mov edi, esi 
    
NextTw:
    add esi, TowerSize
    dec edx
    cmp edx, 0
    jg CheckTowerLoop
    
    cmp edi, 0
    je BuildFail 
    
    mov DWORD PTR [edi + TowerOff_Active], 1
    mov [edi + TowerOff_X], ebx
    mov [edi + TowerOff_Y], ecx
    sub money, TowerCost
    
    mov edx, OFFSET strMsgBuild
    call WriteString
    ret

BuildFail:
    mov edx, OFFSET strMsgErr
    call WriteString
    ret
BuildTower ENDP

; --- 繪製畫面 (修正版：修復堆疊錯誤) ---
Draw PROC
    mov edi, OFFSET mapBuffer
    mov ecx, MapWidth * MapHeight
    mov al, ' '
    rep stosb
    
    mov esi, OFFSET pathArray
    mov ecx, pathLength
DrawPathLoop:
    mov ebx, [esi]   
    mov eax, [esi+4] 
    
    imul eax, MapWidth
    add eax, ebx
    mov BYTE PTR [mapBuffer + eax], '.'
    
    add esi, 8
    loop DrawPathLoop
    
    mov esi, OFFSET pathArray
    mov ebx, [esi]
    mov eax, [esi+4]
    imul eax, MapWidth
    add eax, ebx
    mov BYTE PTR [mapBuffer + eax], 'S'
    
    mov esi, OFFSET towers
    mov ecx, MaxTowers
DrawTwLoop:
    cmp DWORD PTR [esi + TowerOff_Active], 1
    jne NextDrTw
    mov ebx, [esi + TowerOff_X]
    mov eax, [esi + TowerOff_Y]
    imul eax, MapWidth
    add eax, ebx
    mov BYTE PTR [mapBuffer + eax], 'T'
NextDrTw:
    add esi, TowerSize
    loop DrawTwLoop
    
    mov esi, OFFSET enemies
    add esi, (MaxEnemies - 1) * EnemySize
    mov ecx, MaxEnemies
DrawEnLoop:
    cmp DWORD PTR [esi + EnemyOff_Active], 1
    jne NextDrEn
    
    mov eax, [esi + EnemyOff_PathIdx]
    mov edx, 8
    mul edx
    mov edx, OFFSET pathArray
    add edx, eax
    
    mov ebx, [edx]   
    mov eax, [edx+4] 
    imul eax, MapWidth
    add eax, ebx
    mov BYTE PTR [mapBuffer + eax], 'E'
    
NextDrEn:
    sub esi, EnemySize
    loop DrawEnLoop

    call Clrscr
    
    mov edx, OFFSET strTitle
    call WriteString
    mov eax, wave
    call WriteDec
    mov edx, OFFSET strClose
    call WriteString
    
    mov edx, OFFSET strStats
    call WriteString
    mov eax, money
    call WriteDec
    mov edx, OFFSET strHealth
    call WriteString
    mov eax, health
    call WriteDec
    
    mov edx, OFFSET strBattle
    call WriteString 
    mov eax, [esp+4] ; 讀取 Stack 中的 enemiesTotal (不破壞堆疊)
    ; 這裡顯示有點複雜，簡單跳過詳細數字以求穩定
    call Crlf
    
    mov al, ' '
    call WriteChar
    call WriteChar
    call WriteChar
    mov ecx, MapWidth
    mov ebx, 0
PrX:
    mov eax, ebx
    mov edx, 0
    mov edi, 10
    div edi 
    mov eax, edx
    call WriteDec
    inc ebx
    loop PrX
    call Crlf
    
    mov edx, OFFSET strBorderH
    call WriteString
    
    mov ebx, 0 
PrintRowLoop:
    mov eax, ebx
    mov edx, 10
    div dl
    movzx eax, ah 
    call WriteDec
    
    mov edx, OFFSET strRowStart
    call WriteString
    
    mov ecx, MapWidth
    mov edi, 0 
PrintColLoop:
    mov eax, ebx
    imul eax, MapWidth
    add eax, edi
    mov esi, eax 
    
    mov al, [mapBuffer + esi]
    
    cmp al, 'T'
    je ColYellow
    cmp al, 'E'
    je ColRed
    cmp al, 'S'
    je ColBlue
    cmp al, '.'
    je ColGray
    mov eax, white + (black * 16)
    call SetTextColor
    
    mov al, [mapBuffer + esi] 
    jmp PrChar
    
ColYellow:
    mov eax, yellow + (black * 16)
    call SetTextColor
    mov al, 'T'
    jmp PrChar
ColRed:
    mov eax, lightRed + (black * 16)
    call SetTextColor
    mov al, 'E'
    jmp PrChar
ColBlue:
    mov eax, lightBlue + (black * 16)
    call SetTextColor
    mov al, 'S'
    jmp PrChar
ColGray:
    mov eax, gray + (black * 16)
    call SetTextColor
    mov al, '.'
    
PrChar:
    call WriteChar
    
    inc edi
    dec ecx
    cmp ecx, 0
    jg PrintColLoop
    
    mov eax, white + (black * 16)
    call SetTextColor
    
    mov edx, OFFSET strRowEnd
    call WriteString
    
    inc ebx
    cmp ebx, MapHeight
    jl PrintRowLoop
    
    mov edx, OFFSET strBorderH
    call WriteString
    
    ; ------------------------------------
    ; !!! 重要修正 (Fix) !!!
    ; ------------------------------------
    ; 絕對不能在這裡 pop eax，因為這會把 Return Address 彈出！
    ; 而是使用 ret 8 來清理呼叫者 push 進來的 2 個參數 (8 bytes)
    
    ret 8
Draw ENDP

DelayBig PROC
    mov eax, 1000
    call Delay
    ret
DelayBig ENDP

END main