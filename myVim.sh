#第一个参数为打开的文件名
fileName=$1
#初始化，把内容存进content变量，标记当前位置为1，1，mode为normal
content=$(cat "$1")
curRow=1
curLine=1
mode=0 # modes: 0 normal 1 command 2 insert
isNu=1 #默认显示行号


#打印文本的函数
function Print()
{
    #清屏
    clear
    modeName=""
    #计算行数和字节数
    lines=$(echo "$content" | wc -l)
    bytes=$(echo "$content" | wc -c)
    
    #打印文本
    if [ $isNu -eq 1 ]
    then
        echo "$content" | nl -b a -n rn -w 1
    else
        echo "$content"
    fi

    case $mode in
    0)
        #打印附加信息
        modeName="---NORMAL---"
        echo $modeName
        echo "\"$fileName\" ""$lines""L, ""$bytes""B    Loc: $curRow,$curLine"

        #调整光标位置至第一个字
        if [ $isNu -eq 1 ]
        then
            cursorLine=$(($curLine+8))
        else
            cursorLine=$(($curLine))
        fi
        printf "\033[?25h"
        printf "\33[%d;%dH" $curRow $cursorLine 
        ;;
    1)
        modeName="---COMMAND---"
        echo $modeName
        echo "\"$fileName\" ""$lines""L, ""$bytes""B    Loc: $curRow,$curLine"
        
        #调整光标位置至最末
        printf "\033[?25h"
        cursorRow=$(($lines+3))
        printf "\33[%d;1H" $cursorRow
        printf ":"
        ;;
    2)
        modeName="---INSERT---"
        echo $modeName
        echo "\"$fileName\" ""$lines""L, ""$bytes""B    Loc: $curRow,$curLine"

        #调整光标位置至第一个字
        if [ $isNu -eq 1 ]
        then
            cursorLine=$(($curLine+8))
        else
            cursorLine=$(($curLine))
        fi
        printf "\033[?25h"
        printf "\33[%d;%dH" $curRow $cursorLine 
        ;;
    esac
}

#解析命令和输入键的函数
function Parser()
{
    #读取输入的信息
    word=$1

    #如果是esc键，恢复normal模式
    if [ $word == $'\E' ]
    then
        mode=0
    fi

    case $mode in 
    0) #normal模式
        case $word in
        h|$'\E[D')
            #光标向左移动
            if [ $curLine -gt 1 ]
            then
                curLine=$(($curLine-1)) #列向左一个字符
            fi
            ;;
        j|$'\E[B')
            if [ $curRow -lt $lines ]
            then
                #向下一行
                curRow=$(($curRow+1))
                #计算下一行的字符数
                btmNum=$(echo "$content" | sed -n "$curRow"p | wc -c | awk '{print $0-1}')

                #如果上一行的位置大于下一行字符数，那么光标移到下一行末尾
                if [ $btmNum -lt $curLine ]
                then
                    curLine=$(($btmNum))
                fi
                #防止光标移到0的位置
                if [ $btmNum -eq 0 ]
                then
                    curLine=1
                fi
            fi 
            ;;
        k|$'\E[A')
            if [ $curRow -gt 1 ]
            then
                #向上一行
                curRow=$(($curRow-1))
                #计算上一行字符数
                topNum=$(echo "$content" | sed -n "$curRow"p | wc -c | awk '{print $0-1}')

                #位置判定
                if [ $topNum -lt $curLine ]
                then
                    curLine=$(($topNum))
                fi
                if [ $topNum -eq 0 ]
                then
                    curLine=1
                fi
            fi 
            ;;
        l|$'\E[C')
            #向右一位
            #计算该行字符数，不能超过这个位置
            charNum=$(echo "$content" | sed -n "$curRow"p | wc -c | awk '{print $0-1}')
            if [ $curLine -lt $charNum ]
            then
                ((curLine+=1))
            fi ;;
        i)
            #转换为insert模式
            mode=2 ;;
        :|/)
            #转换为command模式
            mode=1 
            ;;
        esac ;;
    1)
        #command模式，读取一行命令
        case $word in
        n)
            #进入normal模式
            mode=0
            ;;
        i)
            #进入insert模式
            mode=2
            ;;
        w)
            #保存
            echo "$content" > $fileName
            ;;
        wq)
            #保存并退出
            echo "$content" > $fileName
            clear
            exit 0 
            ;;
        q)
            #退出
            clear
            exit 0 
            ;;
        'set nu')
            #显示行号
            isNu=1
            ;;
        'set nonu')
            #不显示行号
            isNu=0
            ;;
        esac ;;
    2) # insert mode
        case $word in
        #四个键与normal类似，但是该模式下光标可以移动到文字后
        $'\E[D')
            (($curLine > 1)) && ((curLine-=1)) ;;
        $'\E[B')
            if [ $curRow -lt $lines ]
            then
                #向下一行
                curRow=$(($curRow+1))
                btmNum=$(echo "$content" | sed -n "$curRow"p | wc -c | awk '{print $0-1}')
                btmNum=$(($btmNum+1))

                if [ $btmNum -lt $curLine ]
                then
                    curLine=$(($btmNum))
                fi
            fi ;;
        $'\E[A')
            if [ $curRow -gt 1 ]
            then
                #向上一行
                curRow=$(($curRow-1))
                topNum=$(echo "$content" | sed -n "$curRow"p | wc -c | awk '{print $0-1}')
                topNum=$(($topNum+1))

                if [ $topNum -lt $curLine ]
                then
                    curLine=$(($topNum))
                fi
            fi ;;
        $'\E[C')
            charNum=$(echo "$content" | sed -n "$curRow"p | wc -c | awk '{print $0-1}')
            if [ $curLine -le $charNum ]
            then
                ((curLine+=1))
            fi ;;
        $'') #输出回车，换行
            if [ $curLine -gt 1 ]
            then
                #在光标位置增加一个回车字符，换行
                content=$(echo "$content" | sed "$(($curRow))s/./&\n/$(($curLine-1))")
            else
                #在第一个字符左面换行，直接插入一个空行
                content=$(echo "$content" | sed "$curRow{x;p;x;}")
            fi
            curRow=$(($curRow+1))
            curLine=1
            ;;
        $'\E[3~') # 删除光标后面的字符
            content=$(echo "$content" | sed "$(($curRow))s/\(.\{$(($curLine-1))\}\).\(.*\)/\1\2/")
            ;;
        $'\177') #退格键
            if [ $curLine -gt 1 ]
            then
                #删除光标位置前面的字符
                content=$(echo "$content" | sed "$(($curRow))s/\(.\{$(($curLine-2))\}\).\(.*\)/\1\2/")
                curLine=$(($curLine-1))
            elif [ $curRow -gt 1 ]
            then
                #需要退行的处理
                curRow=$(($curRow-1))
                curLine=$(echo "$content" | sed -n "$curRow"p | wc -c | awk '{print $0-1}')
                curLine=$(($curLine+1))
                #使用awk脚本处理
                content=$(echo "$content" | awk '{if(NR == "'$curRow'"){top=$0;getline;print top$0}else{print $0}}')
            fi
            ;;
        *)
            #其余字符视为输入，在光标位置后加该字符
            content=$(echo "$content" | sed "$(($curRow))s/.\{$(($curLine-1))\}/&$word/")
            curLine=$(($curLine+1))
            ;;
        esac ;;
    esac
}


Print
#循环处理
while true
do
    #cmd模式读取一行命令
    if [ $mode -eq 1 ]
    then
        read cmd
        Parser "$cmd"
    else
        #其他模式读取字符
        read -s -n 1 input
        read -sN1 -t 0.0001 k1
        read -sN1 -t 0.0001 k2
        read -sN1 -t 0.0001 k3
        input+=${k1}${k2}${k3}

        Parser "$input"
    fi

    Print
done