INCLUDE Irvine32.inc
main          EQU start@0

; --- 遊戲基本數值定義 ---
MapWidth EQU 20 ; 地圖寬度
MapHeight EQU 10 ; 地圖高度
MaxEnemies EQU 50 ; 敵人數量上限
MaxTowers EQU 30 ; 塔數量上限
TowerCost EQU 50 ; 塔價錢
TowerDamage EQU 2 ; 塔傷害
StartBaseHP EQU 3 ; 初始基地血量
StartMoney EQU 120 ; 初始金錢
GameTickMs EQU 250
TowerRange EQU 35 ; 塔射程

; --- 敵人結構定義 (修改: Size變大) ---
EnemySize EQU 24 ; id(4), pathIndex(4), hp(4), maxHp(4), active(4), isHit(4)
EnemyOff_ID EQU 0
EnemyOff_PathIdx EQU 4
EnemyOff_HP EQU 8
EnemyOff_MaxHP EQU 12
EnemyOff_Active EQU 16
EnemyOff_IsHit EQU 20 ; [新增] 受傷閃爍旗標

; --- 塔結構定義 (修改: Size變大) ---
TowerSize EQU 20 ; x(4), y(4), active(4), killCount(4), isAttacking(4)
TowerOff_X EQU 0
TowerOff_Y EQU 4
TowerOff_Active EQU 8
TowerOff_KillCount EQU 12
TowerOff_IsAttacking EQU 16 ; [新增] 攻擊閃爍旗標

WaveToClear EQU 3

.data
    ; --- 遊戲狀態 ---
    money       DWORD ?
    health      DWORD ?
    wave        DWORD ?
    gameOver    DWORD 0
    
    ; --- 地圖資訊 ---
    mapBuffer   BYTE  MapWidth * MapHeight DUP(' ')
    pathArray   DWORD 200 DUP(0)
    pathLength  DWORD 0

    ; --- 塔與敵人資訊 ---
    enemies     BYTE  MaxEnemies * EnemySize DUP(0)
    towers      BYTE  MaxTowers * TowerSize DUP(0)
    
    ; --- 戰鬥階段變數 ---
    tick            DWORD 0
    enemiesSpawned  DWORD 0
    enemiesTotal    DWORD 0
    enemiesAlive    DWORD 0
    
    ; --- 文字內容 ---
    strTitle1   BYTE "=== StageBeta (Wave ", 0
    strTitle2   BYTE ") ===", 0dh, 0ah, 0
    strMoney    BYTE "Money: $", 0
    strHealth   BYTE "  |  Base HP: ", 0
    strPrep     BYTE 0dh, 0ah, "State: [PREP] (b)Build ($50) | (s)Start ", 0dh, 0ah, "Enter command here: ", 0
    strBattle   BYTE 0dh, 0ah, "State: [BATTLE] Enemies Left: ", 0
    strInputX   BYTE "Enter X: ", 0
    strInputY   BYTE "Enter Y: ", 0
    strMsgBuild BYTE ">> Tower Built!", 0dh, 0ah, 0
    strMsgErr01 BYTE ">> Not Enough Money!", 0dh, 0ah, 0 ; 報錯訊息01
    strMsgErr02 BYTE ">> Can Not Set Tower Here, Try Again!", 0dh, 0ah, 0 ; 報錯訊息02
    strMsgErr03 BYTE ">> Build Too Many Towers!", 0dh, 0ah, 0 ; 報錯訊息03
    strLose     BYTE 0dh, 0ah, "=== YOU LOSE !!!===", 0dh, 0ah, "(r)Replay | (q)QuitGame", 0
    strWin      BYTE 0dh, 0ah, "=== StageBeta Cleared !!!===", 0dh, 0ah, "(r)Replay | (q)QuitGame", 0
    strWinWave  BYTE 0dh, 0ah, ">> Wave Cleared! <<", 0dh, 0ah, 0
    strXPos     BYTE "ABCDEFGHIJKLMNOPQRST(X)", 0
    
    strBorderH  BYTE "  +--------------------+", 0dh, 0ah, 0
    strRowStart BYTE " |", 0
    strRowEnd   BYTE "|", 0dh, 0ah, 0

.code
main PROC
GameStart:
    call InitGame ; 初始化遊戲
GameLoop: ; 遊戲主邏輯
    ; 準備階段
    call RunPrepPhase
    
    ; 戰鬥階段
    call RunBattlePhase

    ; 血量歸0，結束遊戲
    cmp health, 0
    jg NextWave
    mov gameOver, 1
    jmp Lose

NextWave:
    cmp wave, WaveToClear
    je Win
    mov eax, wave
    imul eax, 10
    add eax, 30
    add money, eax
    
    inc wave
    jmp GameLoop

Lose: ; 關卡挑戰失敗，顯示失敗文字，給玩家選擇重玩或關掉遊戲
    call Clrscr
    mov edx, OFFSET strLose
    call WriteString
    call Crlf
    call ReadChar
    cmp al, 'r' ;按r重新遊玩
    je GameStart
    cmp al, 'q' ;按q結束遊戲
    je EndGame

    jmp Lose

Win: ; 關卡挑戰成功，顯示通關文字，給玩家選擇重玩或關掉遊戲
    call Clrscr
    mov edx, OFFSET strWin
    call WriteString
    call Crlf
    call ReadChar
    cmp al, 'r' ;按r重新遊玩
    je GameStart
    cmp al, 'q' ;按q結束遊戲
    je EndGame

    jmp Win
EndGame:
    exit
main ENDP

; --- 初始化遊戲 ---
InitGame PROC
    mov money, StartMoney 
    mov health, StartBaseHP
    mov wave, 1
    mov gameOver, 0
    call InitPath
    
    cld
    mov edi, OFFSET towers
    mov ecx, MaxTowers * TowerSize
    mov al, 0
    rep stosb

    mov edi, OFFSET enemies
    mov ecx, MaxEnemies * EnemySize
    mov al, 0
    rep stosb

    ret
InitGame ENDP

; --- 設定路徑，設定S字形路線 ---
InitPath PROC
    mov pathLength, 0
    mov esi, OFFSET pathArray
    
    mov ecx, 0 ; x
    mov edx, 1 ; y
SetHorizontalLine1: ; 設定路徑第一條橫線座標
    mov [esi], ecx
    mov [esi+4], edx
    add esi, 8
    inc pathLength
    inc ecx
    cmp ecx, 15
    jle SetHorizontalLine1
    dec ecx 

SetStraightLine1: ; 設定路徑第一條直線座標
    mov [esi], ecx
    mov [esi+4], edx
    add esi, 8
    inc pathLength
    inc edx
    cmp edx, 6
    jle SetStraightLine1
    dec edx 

SetHorizontalLine2: ; 設定路徑第二條橫線座標
    mov [esi], ecx
    mov [esi+4], edx
    add esi, 8
    inc pathLength
    dec ecx
    cmp ecx, 5
    jge SetHorizontalLine2
    inc ecx 

SetStraightLine2: ; 設定路徑第二條直線座標
    mov [esi], ecx
    mov [esi+4], edx
    add esi, 8
    inc pathLength
    inc edx
    cmp edx, 8
    jle SetStraightLine2
    dec edx 

SetHorizontalLine3: ; 設定路徑第三條橫線座標
    mov [esi], ecx
    mov [esi+4], edx
    add esi, 8
    inc pathLength
    inc ecx
    cmp ecx, MapWidth
    jl SetHorizontalLine3
    ret
InitPath ENDP

; --- 準備階段 ---
RunPrepPhase PROC
PrepLoop:
    push 0 ; 初始化本地變數
    push 0
    call Draw ; 顯示路線
    
    mov edx, OFFSET strPrep ; 顯示準備文字敘述
    call WriteString
    
    call ReadChar ;讀取指令
    
    cmp al, 's' ;按s進入戰鬥
    je StartBattle
    cmp al, 'b' ;按b進入建築模式
    je BuildMode

    jmp PrepLoop

BuildMode: ; 建築模式
    call Crlf
    
    cmp money, TowerCost ; 偵錯: 錢不夠
    jl BuildFailNotEnoughMoney 
    
    ; 輸入 X
    mov edx, OFFSET strInputX
    call WriteString
    call ReadInt
    mov ebx, eax 

    ; 輸入 Y 
    mov edx, OFFSET strInputY
    call WriteString
    call ReadInt
    mov ecx, eax 
    
    call BuildTower
    call DelayBig
    jmp PrepLoop
BuildFailNotEnoughMoney:
    mov edx, OFFSET strMsgErr01
    call WriteString
    call DelayBig
    jmp PrepLoop

StartBattle:
    ret
RunPrepPhase ENDP

; --- [新增] 重置視覺狀態 ---
ResetVisualFlags PROC
    ; 重置敵人受傷狀態
    mov esi, OFFSET enemies
    mov ecx, MaxEnemies
ResetEnLoop:
    mov DWORD PTR [esi + EnemyOff_IsHit], 0
    add esi, EnemySize
    loop ResetEnLoop

    ; 重置塔攻擊狀態
    mov esi, OFFSET towers
    mov ecx, MaxTowers
ResetTwLoop:
    mov DWORD PTR [esi + TowerOff_IsAttacking], 0
    add esi, TowerSize
    loop ResetTwLoop
    ret
ResetVisualFlags ENDP

; --- 戰鬥階段 ---
RunBattlePhase PROC
    mov tick, 0
    mov enemiesSpawned, 0
    mov enemiesAlive, 0
    
    mov eax, wave
    shl eax, 1
    add eax, 6
    mov enemiesTotal, eax

BattleLoop:
    cmp health, 0
    jle EndBattle

    ; [新增] 在邏輯運算前，先重置視覺閃爍狀態
    call ResetVisualFlags 

    mov eax, enemiesSpawned
    cmp eax, enemiesTotal
    jge EnemiesAndTowers
    
    mov eax, tick
    and eax, 3
    cmp eax, 0
    jne EnemiesAndTowers
    
    call SpawnEnemy

EnemiesAndTowers:
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
    mov DWORD PTR [esi + EnemyOff_IsHit], 0 ; 初始化為未受傷
    
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

; --- 塔攻擊 (修改加入變色邏輯) ---
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
    
    cmp ebp, TowerRange
    jg NextEnemyCheck
    
    ; === 攻擊發生 ===
    ; 標記視覺效果
    mov DWORD PTR [esi + TowerOff_IsAttacking], 1
    mov DWORD PTR [edi + EnemyOff_IsHit], 1

    ; 扣血
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
    cmp ebx, 0 ; 偵錯: 位置超出地圖邊界
    jl BuildFailIllegalSetting
    cmp ebx, MapWidth
    jge BuildFailIllegalSetting
    cmp ecx, 0
    jl BuildFailIllegalSetting
    cmp ecx, MapHeight
    jge BuildFailIllegalSetting
    
    push ecx
    push ebx
    mov edx, OFFSET pathArray
    mov eax, pathLength
CheckPath: ; 偵錯: 設在道路上
    cmp [edx], ebx     
    jne NextPath
    cmp [edx+4], ecx   
    jne NextPath
    pop ebx
    pop ecx
    jmp BuildFailIllegalSetting
NextPath:
    add edx, 8
    dec eax
    cmp eax, 0
    jg CheckPath
    pop ebx
    pop ecx
    
    mov esi, OFFSET towers
    mov edi, 0 
    mov edx, MaxTowers
    
CheckTower: ; 偵錯: 重複設在同一位置
    cmp DWORD PTR [esi + TowerOff_Active], 1
    jne IsEmptySlot
    cmp [esi + TowerOff_X], ebx
    jne NextTw
    cmp [esi + TowerOff_Y], ecx 
    je BuildFailIllegalSetting 
    jmp NextTw
    
IsEmptySlot:
    mov edi, esi 
    jmp Build
    
NextTw:
    add esi, TowerSize
    dec edx
    cmp edx, 0
    jg CheckTower
    
    cmp edi, 0
    je BuildFailTooManyTower  
    
Build: 
    mov DWORD PTR [edi + TowerOff_Active], 1
    mov [edi + TowerOff_X], ebx
    mov [edi + TowerOff_Y], ecx
    mov DWORD PTR [edi + TowerOff_IsAttacking], 0
    sub money, TowerCost
    
    mov edx, OFFSET strMsgBuild
    call WriteString
    ret


BuildFailIllegalSetting:
    mov edx, OFFSET strMsgErr02
    call WriteString
    ret

BuildFailTooManyTower:
    mov edx, OFFSET strMsgErr03
    call WriteString
    ret
BuildTower ENDP

; --- 繪製畫面 (修改加入變色判定) ---
Draw PROC
    mov edi, OFFSET mapBuffer
    mov ecx, MapWidth * MapHeight
    mov al, ' '
    rep stosb
    
    mov esi, OFFSET pathArray
    mov ecx, pathLength
DrawPath: ; 生成路線
    mov ebx, [esi]   
    mov eax, [esi+4] 
    
    imul eax, MapWidth
    add eax, ebx
    mov BYTE PTR [mapBuffer + eax], '.'
    
    add esi, 8
    loop DrawPath
    
    mov esi, OFFSET pathArray
    mov ebx, [esi]
    mov eax, [esi+4]
    imul eax, MapWidth
    add eax, ebx
    mov BYTE PTR [mapBuffer + eax], 'S'
    
    mov esi, OFFSET towers
    mov ecx, MaxTowers
DrawTw: ; 生成塔
    cmp DWORD PTR [esi + TowerOff_Active], 1
    jne NextDrTw
    mov ebx, [esi + TowerOff_X]
    mov eax, [esi + TowerOff_Y]
    imul eax, MapWidth
    add eax, ebx
    
    ; [修改] 檢查是否攻擊中，寫入 'A' 或 'T'
    cmp DWORD PTR [esi + TowerOff_IsAttacking], 1
    je SetTowerAttack
    mov BYTE PTR [mapBuffer + eax], 'T'
    jmp NextDrTw
SetTowerAttack:
    mov BYTE PTR [mapBuffer + eax], 'A' ; 特殊字元標記攻擊

NextDrTw:
    add esi, TowerSize
    loop DrawTw

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
    
    ; [修改] 檢查是否受傷，寫入 'H' 或 'E'
    cmp DWORD PTR [esi + EnemyOff_IsHit], 1
    je SetEnemyHit
    mov BYTE PTR [mapBuffer + eax], 'E'
    jmp NextDrEn
SetEnemyHit:
    mov BYTE PTR [mapBuffer + eax], 'H' ; 特殊字元標記受傷
    
NextDrEn:
    sub esi, EnemySize
    loop DrawEnLoop
    
    call Clrscr
    
    mov edx, OFFSET strTitle1
    call WriteString
    mov eax, wave
    call WriteDec
    mov edx, OFFSET strTitle2
    call WriteString
    
    mov edx, OFFSET strMoney
    call WriteString
    mov eax, money
    call WriteDec
    mov edx, OFFSET strHealth
    call WriteString
    mov eax, health
    call WriteDec
    
    call Crlf
    
    mov al, ' '
    call WriteChar
    call WriteChar
    call WriteChar
    mov ecx, MapWidth
    mov ebx, 0
PrX:
    mov edx, OFFSET strXPos
    call WriteString

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
    cmp al, 'A'     ; 攻擊中的塔
    je ColAttack    
    cmp al, 'E'
    je ColMagenta   ; 普通敵人 (紫)
    cmp al, 'H'     ; 受傷的敵人 (紅)
    je ColHit
    cmp al, 'S'
    je ColBlue
    cmp al, '.'
    je ColGray
    
    ; 預設白色
    mov eax, white + (black * 16)
    call SetTextColor
    mov al, [mapBuffer + esi] 
    jmp PrChar
    
ColYellow:
    mov eax, yellow + (black * 16)
    call SetTextColor
    mov al, 'T'
    jmp PrChar

ColAttack:
    mov eax, lightCyan + (black * 16) ; 攻擊顏色
    call SetTextColor
    mov al, 'T' ; 顯示回 T
    jmp PrChar

ColMagenta:
    mov eax, magenta + (black * 16) ; 普通敵人顏色
    call SetTextColor
    mov al, 'E'
    jmp PrChar

ColHit:
    mov eax, lightRed + (black * 16) ; 受傷顏色
    call SetTextColor
    mov al, 'E' ; 顯示回 E
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

    call Crlf
    ret 8
Draw ENDP

DelayBig PROC
    mov eax, 1000
    call Delay
    ret
DelayBig ENDP

END main