INCLUDE Irvine32.inc
main EQU start@0

.data
    ; 定義要輸出的字串，以空字元 (0) 結尾
    message BYTE "Hello, World!", 0

.code
main PROC
    ; 將字串的位址載入到 EDX 暫存器
    mov edx, OFFSET message
    
    ; 呼叫 Irvine32 函式庫的 WriteString 程序來輸出字串
    call WriteString
    
    ; 呼叫 CrLf 程序輸出一個換行符號
    call CrLf

    ; 結束程式
    exit 
main ENDP

END main
