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
    ; --- Logo 上半部 (ARCHLIGHTS) ---
    L1_1 BYTE "   WWWWWWWWW                      WWWW   WWW           WWWWW       WWWWW                 ", 0dh, 0ah, 0
    L1_2 BYTE "  WWW\\\\\WWW                    \\WWW  \\\           \\WWW       \\WWW                  ", 0dh, 0ah, 0
    L1_3 BYTE " \WWW    \WWW  WWWWWWWW   WWWWWW  \WWW  WWWW   WWWWWWW \WWWWWWW   WWWWWWW    WWWWW  WW   ", 0dh, 0ah, 0
    L1_4 BYTE " \WWWWWWWWWWW \\WWW\\WWW WWW\\WWW \WWW \\WWW  WWW\\WWW \WWW\\WWW \\\WWW    \WWW\\  \\    ", 0dh, 0ah, 0
    L1_5 BYTE " \WWW\\\\\WWW  \WWW \\\ \WWW \\\  \WWW  \WWW \WWW \WWW \WWW \WWW   \WWW    \\WWWWW       ", 0dh, 0ah, 0
    L1_6 BYTE " \WWW    \WWW  \WWW     \WWW  WWW \WWW  \WWW \WWW \WWW \WWW \WWW   \WWW WWW \\\\WWW      ", 0dh, 0ah, 0
    L1_7 BYTE " WWWWW   WWWWW WWWWW    \\WWWWWW  WWWWW WWWWW\\WWWWWWW WWWW WWWWW  \\WWWWW  WWWWWW  WW   ", 0dh, 0ah, 0
    L1_8 BYTE "\\\\\   \\\\\ \\\\\      \\\\\\  \\\\\ \\\\\  \\\\\WWW\\\\ \\\\\    \\\\\  \\\\\\  \\    ", 0dh, 0ah, 0
    L1_9 BYTE "                                              WWW \WWW                                   ", 0dh, 0ah, 0
    L1_0 BYTE "                                             \\WWWWWW                                    ", 0dh, 0ah, 0
    L1_A BYTE "                                              \\\\\\                                     ", 0dh, 0ah, 0

    ; --- Logo 下半部 (TOWER DEF) ---
    L2_1 BYTE " WWWWWWWWWWW                                             WWWWWWWWWW               WWWWWW ", 0dh, 0ah, 0
    L2_2 BYTE "\W\\\WWW\\\W                                            \\WWW\\\\WWW             WWW\\WWW", 0dh, 0ah, 0
    L2_3 BYTE "\   \WWW  \   WWWWWW  WWWWW WWW WWWWW  WWWWWW  WWWWWWWW  \WWW   \\WWW  WWWWWW   \WWW \\\ ", 0dh, 0ah, 0
    L2_4 BYTE "    \WWW     WWW\\WWW\\WWW \WWW\\WWW  WWW\\WWW\\WWW\\WWW \WWW    \WWW WWW\\WWW WWWWWWW   ", 0dh, 0ah, 0
    L2_5 BYTE "    \WWW    \WWW \WWW \WWW \WWW \WWW \WWWWWWW  \WWW \\\  \WWW    \WWW\WWWWWWW \\\WWW\    ", 0dh, 0ah, 0
    L2_6 BYTE "    \WWW    \WWW \WWW \\WWWWWWWWWWW  \WWW\\\   \WWW      \WWW    WWW \WWW\\\    \WWW     ", 0dh, 0ah, 0
    L2_7 BYTE "    WWWWW   \\WWWWWW   \\WWWW\WWWW   \\WWWWWW  WWWWW     WWWWWWWWWW  \\WWWWWW   WWWWW    ", 0dh, 0ah, 0
    L2_8 BYTE "   \\\\\     \\\\\\     \\\\ \\\\     \\\\\\  \\\\\     \\\\\\\\\\    \\\\\\   \\\\\     ", 0dh, 0ah, 0

    strStartPrompt BYTE 0dh, 0ah, "                   >> Press [P] to Play | [Q] to Quit <<", 0dh, 0ah, 0

    ; --- 遊戲狀態 ---
    money       DWORD ?
    health      DWORD ?
    wave        DWORD ?
    gameOver    DWORD 0
    towersBuilt DWORD 0
    
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
	strSetWindow BYTE "mode con: cols=100 lines=40", 0
    strTitle1   BYTE "=== StageBeta (Wave ", 0
    strTitle2   BYTE ") ===", 0dh, 0ah, 0
    strMoney    BYTE "Money: $", 0
    strHealth   BYTE "  |  Base HP: ", 0
    strPrep     BYTE 0dh, 0ah, "State: [PREP] (b)Build ($50) | (s)Start | (q)Quit ", 0dh, 0ah, "Enter command here: ", 0
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
	
	; --- 側邊欄文字 --- 
    strSideWave    BYTE "Current Wave: ", 0
    strSideMaxWave BYTE " / 3", 0
    strSideMoney   BYTE "Money: $", 0
    strSideTower   BYTE "Tower: [T] ($50)", 0
    strSideHP      BYTE "Base HP: ", 0
    strHeart       BYTE "❤", 0

; --- 遊戲結束資訊 ---
    strGameOverInfo1 BYTE "Waves Cleared: ", 0
    strGameOverInfo2 BYTE "Towers Built: ", 0

; --- 勝利畫面 (亮青色) ---
    W_1 BYTE "  WWWWWWWWW    WWW                                    WWWWWWWWWW             WWW              ", 0dh, 0ah, 0
    W_2 BYTE " WWW\\\\\WWW  \WWW                                   \\WWW\\\\WWW           \WWW              ", 0dh, 0ah, 0
    W_3 BYTE "\WWW    \\\  WWWWWWW    WWWWWW    WWWWWWW  WWWWWW     \WWW   \WWW  WWWWWW  WWWWWWW    WWWWWW  ", 0dh, 0ah, 0
    W_4 BYTE "\\WWWWWWWWW \\\WWW\    \\\\\WWW  WWW\\WWW WWW\\WWW    \WWWWWWWWW  WWW\\WWW\\\WWW\    \\\\\WWW ", 0dh, 0ah, 0
    W_5 BYTE " \\\\\\\\WWW  \WWW      WWWWWWW \WWW \WWW\WWWWWWW     \WWW\\\\WWW\WWWWWWW   \WWW      WWWWWWW ", 0dh, 0ah, 0
    W_6 BYTE " WWW    \WWW  \WWW WWW WWW\\WWW \WWW \WWW\WWW\\\      \WWW   \WWW\WWW\\\    \WWW WWW WWW\\WWW ", 0dh, 0ah, 0
    W_7 BYTE "\\WWWWWWWWW   \\WWWWW \\WWWWWWW \\WWWWWWW\\WWWWWW     WWWWWWWWWW \\WWWWWW   \\WWWWW \\WWWWWWW ", 0dh, 0ah, 0
    W_8 BYTE " \\\\\\\\\     \\\\\   \\\\\\\   \\\\\WWW \\\\\\     \\\\\\\\\\   \\\\\\     \\\\\   \\\\\\\  ", 0dh, 0ah, 0
    W_9 BYTE "                                 WWW \WWW                                                     ", 0dh, 0ah, 0
    W_10 BYTE "                                \\WWWWWW                                                     ", 0dh, 0ah, 0
    W_11 BYTE "                                 \\\\\\                                                      ", 0dh, 0ah, 0
    W_12 BYTE "   WWWWWWWWW  WWWW                                            WWWWW WWW WWW WWW              ", 0dh, 0ah, 0
    W_13 BYTE "  WWW\\\\\WWW\\WWW                                           \\WWW \WWW\WWW\WWW              ", 0dh, 0ah, 0
    W_14 BYTE " WWW     \\\  \WWW   WWWWWW   WWWWWW   WWWWWWWW   WWWWWW   WWWWWWW \WWW\WWW\WWW              ", 0dh, 0ah, 0
    W_15 BYTE "\WWW          \WWW  WWW\\WWW \\\\\WWW \\WWW\\WWW WWW\\WWW WWW\\WWW \WWW\WWW\WWW              ", 0dh, 0ah, 0
    W_16 BYTE "\WWW          \WWW \WWWWWWW   WWWWWWW  \WWW \\\ \WWWWWWW \WWW \WWW \WWW\WWW\WWW              ", 0dh, 0ah, 0
    W_17 BYTE "\\WWW     WWW \WWW \WWW\\\   WWW\\WWW  \WWW     \WWW\\\  \WWW \WWW \\\ \\\ \\\               ", 0dh, 0ah, 0
    W_18 BYTE " \\WWWWWWWWW  WWWWW\\WWWWWW \\WWWWWWW  WWWWW    \\WWWWWW \\WWWWWWWW WWW WWW WWW              ", 0dh, 0ah, 0
    W_19 BYTE "  \\\\\\\\\  \\\\\  \\\\\\   \\\\\\\  \\\\\      \\\\\\   \\\\\\\\ \\\ \\\ \\\               ", 0dh, 0ah, 0

    ; --- 失敗畫面 (紅色) ---
    L_1 BYTE "   WWWWWWWWW                                    ", 0dh, 0ah, 0
    L_2 BYTE "  WWW\\\\\WWW                                   ", 0dh, 0ah, 0
    L_3 BYTE " WWW     \\\   WWWWWW   WWWWWWWWWWWWW    WWWWWW ", 0dh, 0ah, 0
    L_4 BYTE "\WWW          \\\\\WWW \\WWW\\WWW\\WWW  WWW\\WWW", 0dh, 0ah, 0
    L_5 BYTE "\WWW    WWWWW  WWWWWWW  \WWW \WWW \WWW \WWWWWWW ", 0dh, 0ah, 0
    L_6 BYTE "\\WWW  \\WWW  WWW\\WWW  \WWW \WWW \WWW \WWW\\\  ", 0dh, 0ah, 0
    L_7 BYTE " \\WWWWWWWWW \\WWWWWWWW WWWWW\WWW WWWWW\\WWWWWW ", 0dh, 0ah, 0
    L_8 BYTE "  \\\\\\\\\   \\\\\\\\ \\\\\ \\\ \\\\\  \\\\\\  ", 0dh, 0ah, 0
    L_9 BYTE "                                                ", 0dh, 0ah, 0
    L_10 BYTE "    WWWWWWW                                     ", 0dh, 0ah, 0
    L_11 BYTE "  WWW\\\\\WWW                                   ", 0dh, 0ah, 0
    L_12 BYTE " WWW     \\WWW WWWWW WWWWW  WWWWWW  WWWWWWWW    ", 0dh, 0ah, 0
    L_13 BYTE "\WWW      \WWW\\WWW \\WWW  WWW\\WWW\\WWW\\WWW   ", 0dh, 0ah, 0
    L_14 BYTE "\WWW      \WWW \WWW  \WWW \WWWWWWW  \WWW \\\    ", 0dh, 0ah, 0
    L_15 BYTE "\\WWW     WWW  \\WWW WWW  \WWW\\\   \WWW        ", 0dh, 0ah, 0
    L_16 BYTE " \\\WWWWWWW\    \\WWWWW   \\WWWWWW  WWWWW       ", 0dh, 0ah, 0
    L_17 BYTE "   \\\\\\\       \\\\\     \\\\\\  \\\\\        ", 0dh, 0ah, 0
    
    strRetryPrompt BYTE 0dh, 0ah, "             >> Press [R] to Replay | [Q] to Quit <<", 0dh, 0ah, 0

.code
main PROC
GameStart:
	mov edx, OFFSET strSetWindow
	; call Win32_System_Command
	call ShowStartScreen ; 先顯示起始畫面，玩家按 P 才會繼續
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

LoseOld: 
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

WinOld: 
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
	
Lose: ; 關卡挑戰失敗，顯示失敗文字，給玩家選擇重玩或關掉遊戲
    call Clrscr
    mov eax, lightRed + (black * 16)
    call SetTextColor
    
    ; 迴圈印出失敗 ASCII (這裡示範前幾行，實際請補齊 L_1 ~ L_17)
    mov edx, OFFSET L_1
    call WriteString
    mov edx, OFFSET L_2
    call WriteString
    mov edx, OFFSET L_3
    call WriteString
    mov edx, OFFSET L_4
    call WriteString
    mov edx, OFFSET L_5
    call WriteString
    mov edx, OFFSET L_6
    call WriteString
    mov edx, OFFSET L_7
    call WriteString
    mov edx, OFFSET L_8
    call WriteString
    mov edx, OFFSET L_9
    call WriteString
    mov edx, OFFSET L_10
    call WriteString
    mov edx, OFFSET L_11
    call WriteString
    mov edx, OFFSET L_12
    call WriteString
    mov edx, OFFSET L_13
    call WriteString
    mov edx, OFFSET L_14
    call WriteString
    mov edx, OFFSET L_15
    call WriteString
    mov edx, OFFSET L_16
    call WriteString
    mov eax, white + (black * 16)
    call SetTextColor

    ; --- Display Stats ---
    call Crlf
    mov edx, OFFSET strGameOverInfo1
    call WriteString
    mov eax, wave
    dec eax ; waves cleared = current wave - 1
    call WriteDec
    call Crlf

    mov edx, OFFSET strGameOverInfo2
    call WriteString
    mov eax, towersBuilt
    call WriteDec
    call Crlf

    mov edx, OFFSET strRetryPrompt
    call WriteString

L_WaitLose:
    call ReadChar
    cmp al, 'r'
    je GameStart
    cmp al, 'q'
    je EndGame
    jmp L_WaitLose

Win: ; 關卡挑戰成功，顯示通關文字，給玩家選擇重玩或關掉遊戲
    call Clrscr
    mov eax, lightCyan + (black * 16)
    call SetTextColor
    
    ; 印出勝利 ASCII (W_1 ~ W_19)
    mov edx, OFFSET W_1
    call WriteString
    mov edx, OFFSET W_2
    call WriteString
    mov edx, OFFSET W_3
    call WriteString
    mov edx, OFFSET W_4
    call WriteString
    mov edx, OFFSET W_5
    call WriteString
    mov edx, OFFSET W_6
    call WriteString
    mov edx, OFFSET W_7
    call WriteString
    mov edx, OFFSET W_8
    call WriteString
    mov edx, OFFSET W_9
    call WriteString
    mov edx, OFFSET W_10
    call WriteString
    mov edx, OFFSET W_11
    call WriteString
    mov edx, OFFSET W_12
    call WriteString
    mov edx, OFFSET W_13
    call WriteString
    mov edx, OFFSET W_14
    call WriteString
    mov edx, OFFSET W_15
    call WriteString
    mov edx, OFFSET W_16
    call WriteString
    mov edx, OFFSET W_17
    call WriteString
    mov edx, OFFSET W_18
    call WriteString
    mov edx, OFFSET W_19
    call WriteString

    mov eax, white + (black * 16)
    call SetTextColor

    ; --- Display Stats ---
    call Crlf
    mov edx, OFFSET strGameOverInfo1
    call WriteString
    mov eax, wave
    call WriteDec
    call Crlf

    mov edx, OFFSET strGameOverInfo2
    call WriteString
    mov eax, towersBuilt
    call WriteDec
    call Crlf

    mov edx, OFFSET strRetryPrompt
    call WriteString

L_WaitWin:
    call ReadChar
    cmp al, 'r'
    je GameStart
    cmp al, 'q'
    je EndGame
    jmp L_WaitWin
	
EndGame:
    exit
main ENDP

; --- 初始化遊戲 ---
ShowStartScreen PROC
    call Clrscr
    
    ; --- 印出上半部 (亮黃色) ---
    mov eax, yellow + (black * 16)
    call SetTextColor
    mov edx, OFFSET L1_1
    call WriteString
    mov edx, OFFSET L1_2
    call WriteString
    mov edx, OFFSET L1_3
    call WriteString
    mov edx, OFFSET L1_4
    call WriteString
    mov edx, OFFSET L1_5
    call WriteString
    mov edx, OFFSET L1_6
    call WriteString
    mov edx, OFFSET L1_7
    call WriteString
    mov edx, OFFSET L1_8
    call WriteString
    mov edx, OFFSET L1_9
    call WriteString
    mov edx, OFFSET L1_0
    call WriteString
    mov edx, OFFSET L1_A
    call WriteString

    ; --- 印出下半部 (亮紫色) ---
    mov eax, lightMagenta + (black * 16)
    call SetTextColor
    mov edx, OFFSET L2_1
    call WriteString
    mov edx, OFFSET L2_2
    call WriteString
    mov edx, OFFSET L2_3
    call WriteString
    mov edx, OFFSET L2_4
    call WriteString
    mov edx, OFFSET L2_5
    call WriteString
    mov edx, OFFSET L2_6
    call WriteString
    mov edx, OFFSET L2_7
    call WriteString
    mov edx, OFFSET L2_8
    call WriteString

    ; --- 印出提示文字 (亮白色閃爍感) ---
    mov eax, white + (black * 16)
    call SetTextColor
    mov edx, OFFSET strStartPrompt
    call WriteString

L_Wait:
    call ReadChar
    cmp al, 'p'
    je L_Done
    cmp al, 'P'
    je L_Done
    cmp al, 'q'
    je L_Quit
    cmp al, 'Q'
    je L_Quit
    jmp L_Wait

L_Quit:
    exit
L_Done:
    ret
ShowStartScreen ENDP

InitGame PROC
    mov money, StartMoney 
    mov health, StartBaseHP
    mov wave, 1
    mov gameOver, 0
    mov towersBuilt, 0
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
    je EndPrep
    cmp al, 'b' ;按b進入建築模式
    je BuildMode
    cmp al, 'q'
    je PlayerQuit
    cmp al, 'Q'
    je PlayerQuit

    jmp PrepLoop

BuildMode: ; 建築模式
    call Crlf
    
    cmp money, TowerCost ; 偵錯: 錢不夠
    jl BuildFailNotEnoughMoney 
    
    ; 輸入 X (可接受 'A'-'T' 或 'a'-'t')
    mov edx, OFFSET strInputX
    call WriteString
    call ReadChar
    call Crlf

    ; 轉換小寫為大寫
    cmp al, 'a'
    jb CheckUpperX
    cmp al, 'z'
    ja CheckUpperX
    sub al, ('a' - 'A')

CheckUpperX:
    ; 驗證輸入並轉換
    cmp al, 'A'
    jb PrepLoop ; Invalid input, go back to menu
    cmp al, 'T'
    ja PrepLoop ; Invalid input, go back to menu

    ; 轉換 'A'-'T' 為 0-19
    sub al, 'A'
    movzx ebx, al
    
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

PlayerQuit:
    mov health, 0
    jmp EndPrep

EndPrep:
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
    inc towersBuilt
    
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