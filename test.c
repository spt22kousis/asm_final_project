#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

// --- 跨平台延遲設定 ---
#ifdef _WIN32
#include <windows.h>
#define SLEEP_MS(x) Sleep(x)
#define CLEAR_SCREEN "cls"
#else
#include <unistd.h>
#define SLEEP_MS(x) usleep((x) * 1000)
#define CLEAR_SCREEN "clear"
#endif

// --- 遊戲常數 ---
#define WIDTH 20
#define HEIGHT 10
#define MAX_ENEMIES_PER_WAVE 50
#define MAX_TOWERS 30
#define TOWER_COST 50
#define TOWER_RANGE 3.5
#define TOWER_DAMAGE 2
#define BASE_HP 20
#define START_MONEY 150
#define GAME_TICK_MS 250 // 遊戲更新頻率 (毫秒)

// --- 結構定義 ---
typedef struct
{
    int x, y;
} Point;

typedef struct
{
    int id;
    int pathIndex;
    int hp;
    int maxHp;
    int active;
} Enemy;

typedef struct
{
    int x, y;
    int active;
    int killCount; // 記錄塔殺了多少敵人
} Tower;

typedef struct
{
    int money;
    int health;
    int wave;
    int gameOver;
    char displayMap[HEIGHT][WIDTH];
} GameState;

// --- 全域變數 ---
GameState game;
Enemy enemies[MAX_ENEMIES_PER_WAVE];
Tower towers[MAX_TOWERS];
Point path[100];
int pathLength = 0;

// --- 函數宣告 ---
void initGame();
void initPath();
void draw(int isBattlePhase, int enemiesLeft, int enemiesToSpawn);
void runPrepPhase();
void runBattlePhase();
void buildTower();
double getDistance(int x1, int y1, int x2, int y2);

// --- 主程式 ---
int main()
{
    initGame();

    while (!game.gameOver)
    {
        // 1. 準備階段 (玩家操作)
        runPrepPhase();

        if (game.gameOver)
            break; // 如果在準備階段退出

        // 2. 戰鬥階段 (自動執行)
        runBattlePhase();

        // 檢查是否遊戲結束
        if (game.health <= 0)
        {
            game.gameOver = 1;
            system(CLEAR_SCREEN);
            printf("\n\n=== 遊戲結束 ===\n");
            printf("你存活了 %d 波\n", game.wave - 1);
            break;
        }

        // 波次結束獎勵
        game.money += 50 + (game.wave * 10);
        game.wave++;
    }

    return 0;
}

// --- 階段邏輯 ---

// 準備階段：玩家可以一直蓋塔，直到輸入 start
void runPrepPhase()
{
    char input[20];
    while (1)
    {
        draw(0, 0, 0); // 0 = 準備階段
        printf("\n--- 第 %d 波 準備階段 ---\n", game.wave);
        printf("[指令] (b): 建造塔($%d) | (s): 開始戰鬥 | (q): 退出遊戲\n", TOWER_COST);
        printf("輸入指令: ");

        fgets(input, sizeof(input), stdin);

        if (input[0] == 'q' || input[0] == 'Q')
        {
            game.gameOver = 1;
            return;
        }
        else if (input[0] == 's' || input[0] == 'S')
        {
            return; // 結束準備，進入戰鬥
        }
        else if (input[0] == 'b' || input[0] == 'B')
        {
            buildTower();
        }
    }
}

// 戰鬥階段：自動迴圈，直到所有敵人死亡或生成完畢
void runBattlePhase()
{
    int tick = 0;
    int enemiesSpawned = 0;
    int enemiesTotal = 5 + (game.wave * 2); // 每波敵人數量增加
    int enemiesAlive = 0;

    // 重置敵人列表
    for (int i = 0; i < MAX_ENEMIES_PER_WAVE; i++)
        enemies[i].active = 0;

    printf("戰鬥開始！\n");
    SLEEP_MS(1000);

    while (game.health > 0)
    {
        // 1. 生成敵人 (每 4 ticks 生成一隻，約 1秒)
        if (enemiesSpawned < enemiesTotal && tick % 4 == 0)
        {
            for (int i = 0; i < MAX_ENEMIES_PER_WAVE; i++)
            {
                if (!enemies[i].active)
                {
                    enemies[i].active = 1;
                    enemies[i].pathIndex = 0;
                    // 敵人血量隨波數成長
                    enemies[i].maxHp = 5 + (game.wave * 3);
                    enemies[i].hp = enemies[i].maxHp;
                    enemies[i].id = i;
                    enemiesSpawned++;
                    enemiesAlive++;
                    break;
                }
            }
        }

        // 2. 移動敵人
        for (int i = 0; i < MAX_ENEMIES_PER_WAVE; i++)
        {
            if (enemies[i].active)
            {
                enemies[i].pathIndex++;
                if (enemies[i].pathIndex >= pathLength)
                {
                    enemies[i].active = 0;
                    game.health--;
                    enemiesAlive--;
                }
            }
        }

        // 3. 塔攻擊
        for (int t = 0; t < MAX_TOWERS; t++)
        {
            if (!towers[t].active)
                continue;

            int targetIdx = -1;
            double minDst = 999.0;

            // 找最近的敵人
            for (int e = 0; e < MAX_ENEMIES_PER_WAVE; e++)
            {
                if (!enemies[e].active)
                    continue;

                int ex = path[enemies[e].pathIndex].x;
                int ey = path[enemies[e].pathIndex].y;
                double dst = getDistance(towers[t].x, towers[t].y, ex, ey);

                if (dst <= TOWER_RANGE && dst < minDst)
                {
                    minDst = dst;
                    targetIdx = e;
                }
            }

            if (targetIdx != -1)
            {
                enemies[targetIdx].hp -= TOWER_DAMAGE;
                if (enemies[targetIdx].hp <= 0)
                {
                    enemies[targetIdx].active = 0;
                    enemiesAlive--;
                    game.money += 5 + game.wave; // 擊殺獎勵
                    towers[t].killCount++;
                }
            }
        }

        // 4. 繪圖與延遲
        draw(1, enemiesAlive, enemiesTotal - enemiesSpawned);

        // 5. 判斷波次結束條件 (都生成完了 且 場上沒活人了)
        if (enemiesSpawned >= enemiesTotal && enemiesAlive == 0)
        {
            printf("\n>> 第 %d 波 防守成功！ <<\n", game.wave);
            SLEEP_MS(2000); // 讓玩家看到結果
            break;
        }

        tick++;
        SLEEP_MS(GAME_TICK_MS);
    }
}

// --- 輔助功能實作 ---

void initPath()
{
    // S型路徑
    int idx = 0;
    int r = 1, c = 0;
    for (; c <= 15; c++)
    {
        path[idx].x = c;
        path[idx].y = r;
        idx++;
    }
    c--;
    for (; r <= 6; r++)
    {
        path[idx].x = c;
        path[idx].y = r;
        idx++;
    }
    r--;
    for (; c >= 5; c--)
    {
        path[idx].x = c;
        path[idx].y = r;
        idx++;
    }
    c++;
    for (; r <= 8; r++)
    {
        path[idx].x = c;
        path[idx].y = r;
        idx++;
    }
    r--;
    for (; c < WIDTH; c++)
    {
        path[idx].x = c;
        path[idx].y = r;
        idx++;
    }
    pathLength = idx;
}

void initGame()
{
    game.money = START_MONEY;
    game.health = BASE_HP;
    game.wave = 1;
    game.gameOver = 0;
    initPath();
    for (int i = 0; i < MAX_TOWERS; i++)
        towers[i].active = 0;
}

double getDistance(int x1, int y1, int x2, int y2)
{
    return sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2));
}

void buildTower()
{
    if (game.money < TOWER_COST)
    {
        printf(">> 資金不足！需要 $%d\n", TOWER_COST);
        return;
    }
    int x, y;
    printf("輸入座標 (x y): ");
    if (scanf("%d %d", &x, &y) != 2)
    {
        while (getchar() != '\n')
            ;
        return;
    }
    while (getchar() != '\n')
        ;

    if (x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT)
    {
        printf(">> 超出範圍！\n");
        return;
    }
    for (int i = 0; i < pathLength; i++)
    {
        if (path[i].x == x && path[i].y == y)
        {
            printf(">> 不能蓋在路徑上！\n");
            return;
        }
    }
    for (int i = 0; i < MAX_TOWERS; i++)
    {
        if (towers[i].active && towers[i].x == x && towers[i].y == y)
        {
            printf(">> 這裡已經有塔了！\n");
            return;
        }
    }
    for (int i = 0; i < MAX_TOWERS; i++)
    {
        if (!towers[i].active)
        {
            towers[i].active = 1;
            towers[i].x = x;
            towers[i].y = y;
            towers[i].killCount = 0;
            game.money -= TOWER_COST;
            printf(">> 建造成功！\n");
            return;
        }
    }
}

void draw(int isBattlePhase, int enemiesLeft, int enemiesToSpawn)
{
    // 準備畫布
    for (int y = 0; y < HEIGHT; y++)
    {
        for (int x = 0; x < WIDTH; x++)
            game.displayMap[y][x] = ' ';
    }

    // 路徑
    for (int i = 0; i < pathLength; i++)
        game.displayMap[path[i].y][path[i].x] = '.';
    game.displayMap[path[0].y][path[0].x] = 'S';
    game.displayMap[path[pathLength - 1].y][path[pathLength - 1].x] = 'B';

    // 塔
    for (int i = 0; i < MAX_TOWERS; i++)
    {
        if (towers[i].active)
            game.displayMap[towers[i].y][towers[i].x] = 'T';
    }

    // 敵人 (只在戰鬥階段顯示)
    if (isBattlePhase)
    {
        for (int i = 0; i < MAX_ENEMIES_PER_WAVE; i++)
        {
            if (enemies[i].active)
            {
                int ex = path[enemies[i].pathIndex].x;
                int ey = path[enemies[i].pathIndex].y;
                game.displayMap[ey][ex] = 'E';
            }
        }
    }

    // 渲染
    system(CLEAR_SCREEN);
    printf("=== C 語言自動塔防 (第 %d 波) ===\n", game.wave);
    printf("金錢: $%d  |  基地生命: %d\n", game.money, game.health);
    if (isBattlePhase)
    {
        printf("狀態: [戰鬥中] 敵人剩餘: %d (待生成: %d)\n", enemiesLeft, enemiesToSpawn);
    }
    else
    {
        printf("狀態: [準備中] 請配置防禦塔\n");
    }

    printf("\n   ");
    for (int x = 0; x < WIDTH; x++)
        printf("%d", x % 10);
    printf("\n  +");
    for (int x = 0; x < WIDTH; x++)
        printf("-");
    printf("+\n");

    for (int y = 0; y < HEIGHT; y++)
    {
        printf("%d |", y % 10);
        for (int x = 0; x < WIDTH; x++)
        {
            char c = game.displayMap[y][x];
            // 顏色代碼
            if (c == 'T')
                printf("\033[1;33m%c\033[0m", c); // 黃色塔
            else if (c == 'E')
                printf("\033[1;31m%c\033[0m", c); // 紅色敵人
            else if (c == 'B')
                printf("\033[1;34m%c\033[0m", c); // 藍色基地
            else if (c == '.')
                printf("\033[1;30m%c\033[0m", c); // 灰色路徑
            else
                printf("%c", c);
        }
        printf("|\n");
    }
    printf("  +");
    for (int x = 0; x < WIDTH; x++)
        printf("-");
    printf("+\n");
}