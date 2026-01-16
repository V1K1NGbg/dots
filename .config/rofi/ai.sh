#!/bin/bash

OLLAMA_MODEL="qwen3:8b"
CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/rofi/ai_last_response.txt"

ollama_status_line() {
	if ! command -v docker &>/dev/null; then
		echo "🐳 Docker: not installed"
		return
	fi

	local status
	status=$(docker inspect -f '{{.State.Status}}' ollama 2>/dev/null)

	case "$status" in
		running)
			echo "🟢 Ollama: running"
			;;
		created|restarting)
			echo "🟡 Ollama: $status"
			;;
		exited|dead)
			echo "🔴 Ollama: $status"
			;;
		*)
			echo "⚪ Ollama: not found"
			;;
	esac
}
store_response() {
	mkdir -p "$(dirname "$CACHE_FILE")"
	printf '%s' "$1" > "$CACHE_FILE"
}

copy_response() {
	local selection="$1"
	local to_copy=$(<"$CACHE_FILE")

	printf '%s' "$to_copy" | xclip -selection clipboard >/dev/null 2>&1
}

call_ollama() {
	local prompt="$1"
	
	# Properly escape the prompt for JSON
	local escaped_prompt=$(printf '%s' "$prompt" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | awk '{printf "%s\\n", $0}' | sed '$ s/\\n$//')
	
	local response=$(curl -s http://localhost:11434/api/generate -d '{
		"model": "'"$OLLAMA_MODEL"'",
		"prompt": "'"$escaped_prompt"'",
		"stream": false
	}')

	local response_text
	# Use jq if available, otherwise fall back to Python for proper JSON parsing
	if command -v jq &>/dev/null; then
		response_text=$(printf '%s' "$response" | jq -r '.response // empty')
	else
		response_text=$(printf '%s' "$response" | python3 -c "import sys, json; print(json.load(sys.stdin).get('response', ''), end='')" 2>/dev/null)
	fi

	response_text=${response_text//$'\r'/}
	store_response "$response_text"

	printf '%s\n' "$response_text" | fold -w 33 -s | sed 's/^/🤖: /'
}
if [[ $# -eq 0 ]]; then
	echo "$(ollama_status_line)"
	echo "💡 Model: $OLLAMA_MODEL"
	echo "---"
	echo "Type your prompt to get a response..."
	echo "Select a response to copy it to clipboard"
	exit 0
fi
case "$1" in
	"🤖: "*)
		copy_response "$1"
		exit 0
		;;
	*)
		call_ollama "$1"
		;;
esac