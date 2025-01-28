#!/bin/bash
if ! command -v yt-dlp &> /dev/null; then
    echo "正在安裝 yt-dlp..."
    sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
    sudo chmod a+rx /usr/local/bin/yt-dlp
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "正在安裝 ffmpeg..."
    sudo apt-get update
    sudo apt-get install -y ffmpeg
fi

DOWNLOAD_DIR="$HOME/Downloads/youtube"
mkdir -p "$DOWNLOAD_DIR"

if ! command -v aria2c &> /dev/null; then
    echo "正在安裝 aria2..."
    sudo apt-get update
    sudo apt-get install -y aria2
fi

check_network() {
    if ping6 -c 1 ipv6.google.com >/dev/null 2>&1; then
        echo "IPv6 連接可用"
        return 0
    else
        echo "IPv6 連接不可用，將使用IPv4"
        return 1
    fi
}

download_video() {
    local video_url=$1
    local choice=$2
    
    local download_opts=(
        --downloader "aria2c"
        --downloader-args "aria2c:-s16 -x16 -k1M --file-allocation=none --optimize-concurrent-downloads=true --async-dns=false"
        -N 8
        --buffer-size 16K
        --file-access-retries 10
        --fragment-retries 10
        --concurrent-fragments 4
        --no-check-certificates
        --prefer-insecure
    )

    if check_network; then
        download_opts+=("--force-ipv6")
    else
        download_opts+=("--force-ipv4")
    fi

    case $choice in
        1)
            echo "開始下載最佳品質影片..."
            yt-dlp "${download_opts[@]}" \
                -f "bestvideo+bestaudio/best" \
                --merge-output-format mp4 \
                -o "$DOWNLOAD_DIR/%(title)s.%(ext)s" \
                "$video_url" || {
                    echo "使用備用下載方式重試..."
                    yt-dlp -f "bestvideo+bestaudio/best" \
                        --merge-output-format mp4 \
                        -o "$DOWNLOAD_DIR/%(title)s.%(ext)s" \
                        "$video_url"
                }
            ;;
        2)
            echo "開始下載720p影片..."
            yt-dlp "${download_opts[@]}" \
                -f "bestvideo[height<=720]+bestaudio/best[height<=720]" \
                --merge-output-format mp4 \
                -o "$DOWNLOAD_DIR/%(title)s.%(ext)s" \
                "$video_url" || {
                    echo "使用備用下載方式重試..."
                    yt-dlp -f "bestvideo[height<=720]+bestaudio/best[height<=720]" \
                        --merge-output-format mp4 \
                        -o "$DOWNLOAD_DIR/%(title)s.%(ext)s" \
                        "$video_url"
                }
            ;;
        3)
            echo "開始下載480p影片..."
            yt-dlp "${download_opts[@]}" \
                -f "bestvideo[height<=480]+bestaudio/best[height<=480]" \
                --merge-output-format mp4 \
                -o "$DOWNLOAD_DIR/%(title)s.%(ext)s" \
                "$video_url" || {
                    echo "使用備用下載方式重試..."
                    yt-dlp -f "bestvideo[height<=480]+bestaudio/best[height<=480]" \
                        --merge-output-format mp4 \
                        -o "$DOWNLOAD_DIR/%(title)s.%(ext)s" \
                        "$video_url"
                }
            ;;
        4)
            echo "開始下載音訊..."
            yt-dlp "${download_opts[@]}" \
                -x --audio-format mp3 \
                -o "$DOWNLOAD_DIR/%(title)s.%(ext)s" \
                "$video_url" || {
                    echo "使用備用下載方式重試..."
                    yt-dlp -x --audio-format mp3 \
                        -o "$DOWNLOAD_DIR/%(title)s.%(ext)s" \
                        "$video_url"
                }
            ;;
        *)
            echo "無效的選項"
            return 1
            ;;
    esac

    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "下載完成"
        rm -f "$DOWNLOAD_DIR"/*
        echo "已清理下載檔案"
        echo "----------------------------------------"
    else
        echo "下載失敗 (錯誤碼: $exit_code)"
        echo "----------------------------------------"
    fi
}

echo "刷Google流量腳本(IPv6優先)"
echo "============================="

echo "請選擇下載模式："
echo "1) 單次下載"
echo "2) 循環下載"
read -p "請選擇模式 (1-2): " mode

echo "請選擇下載選項："
echo "1) 最佳品質影片"
echo "2) 720p影片"
echo "3) 480p影片"
echo "4) 僅音訊 (mp3)"
read -p "請輸入選項編號 (1-4): " choice

read -p "請輸入YouTube影片URL: " video_url

if [ "$mode" = "1" ]; then
    download_video "$video_url" "$choice"
else
    read -p "請輸入每次下載間的休息時間（秒）: " sleep_time
    echo "開始循環下載，按 Ctrl+C 可隨時停止"
    echo "----------------------------------------"
    
    while true; do
        download_video "$video_url" "$choice"
        echo "休息 $sleep_time 秒..."
        sleep "$sleep_time"
    done
fi
