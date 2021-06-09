telegramchatid="xxxx"
telegramkey="xxx"

LOW_PERCEN=50
delay_check_by_endpoint=300
last_time_check_by_endpoint=`date +%s`
last_time_check_by_port=$last_time_check_by_endpoint

sendMessageToTelegram(){
    PAYLOAD=$(echo -e "{\"text\":\"$3\", \"chat_id\":\"$2\"}")
    result=$(curl -X POST -H "Content-Type: application/json" -d "$PAYLOAD" $1)
    echo "$result" >> dhis_service_checker.log
}

while true
do
    NOW=`date +%s`
    DIFF=$(echo "$NOW - $last_time_check_by_endpoint" | bc)
    TOTAL=$(free -m | grep Mem: | awk '{print $2}')
    MEM_AVALAIBLE=$(free -m | grep Mem: | awk '{print $7}')

    PERSEN=$(echo "scale=8; $LOW_PERCEN / 100 * $TOTAL" | bc)
    PERSEN=${PERSEN%\.*}
    
    MEM_USED=$(echo "scale=8; $TOTAL - $MEM_AVALAIBLE" | bc)
    MEM_USED_STATUS="NORMAL"

    MESSAGE="Mem RAM Terpakai $MEM_USED MB, Mem Tersedia $MEM_AVALAIBLE MB dan tidak boleh di bawah $LOW_PERCEN% ( $PERSEN MB )"

    if [ $PERSEN -gt $MEM_AVALAIBLE ]; then
        # echo 'Tolong!!!!,, memory ram hanya tinggal $MEM_AVALAIBLE MB lohhhh' | zenity --notification --listen
        MEM_USED_STATUS="FULL"        
        if [ $DIFF -gt $delay_check_by_endpoint ]; then

            xcounter=0
            XNOTIF_MESSAGE=""
            for pid_result in `sudo smemstat -sm | head -6 | awk '{print $1}'`
            do
                let "xcounter++"
                if [ $xcounter == 1 ]; then
                    message+="\n"
                    continue
                fi
                xmemori_check_result=$(sudo smemstat -sl -p  $pid_result | awk 'FNR == 2')
                
                xmemori=$(echo $xmemori_check_result | awk '{print $4}')
                xuser=$(echo $xmemori_check_result | awk '{print $6}')
                xcommand=$(echo $xmemori_check_result | awk '{print $7}')

                MEMORY_NO_DOT=${xmemori%\.*}
                XMEMORY_FINAL=${MEMORY_NO_DOT%\,*}

                XNOTIF_MESSAGE+="Memori\t: $XMEMORY_FINAL MB \nUser\t: $xuser \nCommand\t: $xcommand\n\n"
            done

            NOTIF_MESSAGE="Warning!!! Mem Server Tersisa $MEM_AVALAIBLE MB.\nBerikut 5 top list pemakaian memory ram :\n\n$XNOTIF_MESSAGE"

            sendMessageToTelegram "https://api.telegram.org/bot$telegramkey/sendMessage" "$telegramchatid" "$NOTIF_MESSAGE" 2>/dev/null
            MESSAGE+=". Notif Terkirim.."
            last_time_check_by_endpoint=`date +%s`
        fi
    fi

    INFORMATION=$( jq -n \
                  --arg RAM_USED "$MEM_USED" \
                  --arg THIS_TIME "$(date '+%Y-%m-%d %H:%M:%S')" \
                  --arg RAM_USED_COUNT "MB" \
                  --arg MEM_USED_STATUS "$MEM_USED_STATUS" \
                  --arg MESSAGE "$MESSAGE" \
                  '{status: $MEM_USED_STATUS, time: $THIS_TIME, ram_used: $RAM_USED, ram_usage_count: $RAM_USED_COUNT, message: $MESSAGE '})
    echo $INFORMATION
    sleep 1
done
