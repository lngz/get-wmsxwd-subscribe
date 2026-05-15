#!/usr/bin/env bash

set -u

LOGIN_URL="https://api.wmsxwd-3.men/api/v1/passport/auth/login"
SUBSCRIBE_URL="https://api.wmsxwd-3.men/api/v1/user/getSubscribe?n=0.543158885715533"
CONFIG_FILE="config.yaml"
LOGIN_UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
DOWNLOAD_UA="clash-verge/v2.4.0"

COOKIE_FILE="$(mktemp)"

cleanup() {
  rm -f "$COOKIE_FILE"
}

trap cleanup EXIT INT TERM

extract_json_string() {
  local input="$1"
  local key="$2"

  printf '%s' "$input" | tr -d '\n' | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p"
}

extract_data_string() {
  local input="$1"

  printf '%s' "$input" | tr -d '\n' | sed -n 's/.*"data"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

read_password() {
  local prompt="$1"
  local password

  printf '%s' "$prompt" >&2
  stty -echo
  IFS= read -r password
  stty echo
  printf '\n' >&2
  printf '%s' "$password"
}

curl_json() {
  local method="$1"
  local url="$2"
  local auth_header="${3:-}"
  local data="${4:-}"
  local output
  local status

  if [ -n "$auth_header" ] && [ -n "$data" ]; then
    output="$(curl --silent --show-error --insecure --location \
      --request "$method" \
      --cookie-jar "$COOKIE_FILE" \
      --cookie "$COOKIE_FILE" \
      --header "Content-Type: application/json" \
      --header "Accept: application/json" \
      --header "Authorization: $auth_header" \
      --user-agent "$LOGIN_UA" \
      --data-raw "$data" \
      "$url" 2>&1)"
    status=$?
  elif [ -n "$auth_header" ]; then
    output="$(curl --silent --show-error --insecure --location \
      --request "$method" \
      --cookie-jar "$COOKIE_FILE" \
      --cookie "$COOKIE_FILE" \
      --header "Content-Type: application/json" \
      --header "Accept: application/json" \
      --header "Authorization: $auth_header" \
      --user-agent "$LOGIN_UA" \
      "$url" 2>&1)"
    status=$?
  elif [ -n "$data" ]; then
    output="$(curl --silent --show-error --insecure --location \
      --request "$method" \
      --cookie-jar "$COOKIE_FILE" \
      --cookie "$COOKIE_FILE" \
      --header "Content-Type: application/json" \
      --header "Accept: application/json" \
      --user-agent "$LOGIN_UA" \
      --data-raw "$data" \
      "$url" 2>&1)"
    status=$?
  else
    output="$(curl --silent --show-error --insecure --location \
      --request "$method" \
      --cookie-jar "$COOKIE_FILE" \
      --cookie "$COOKIE_FILE" \
      --header "Content-Type: application/json" \
      --header "Accept: application/json" \
      --user-agent "$LOGIN_UA" \
      '$url' 2>&1)"
    status=$?
  fi

  if [ $status -ne 0 ]; then
    printf 'curl 执行失败: %s\n' "$output" >&2
    return 1
  fi

  printf '%s' "$output"
}

get_subscribe_url() {
  local email="$1"
  local password="$2"
  local login_payload
  local login_response
  local authorization=""
  local subscribe_response
  local subscribe_url=""

  login_payload="$(printf '{"email":"%s","password":"%s"}' "$email" "$password")"

  printf '\n正在尝试登录用户: %s...\n' "$email" >&2

  login_response="$(curl_json "POST" "$LOGIN_URL" "" "$login_payload")" || return 1

  authorization="$(extract_data_string "$login_response")"
  if [ -z "$authorization" ]; then
    authorization="$(extract_json_string "$login_response" "auth_data")"
  fi
  if [ -z "$authorization" ]; then
    authorization="$(extract_json_string "$login_response" "token")"
  fi

  if [ -z "$authorization" ]; then
    printf '登录失败，请检查账号密码或网站状态。\n' >&2
    printf '返回信息: %s\n' "$login_response" >&2
    return 1
  fi

  printf '登录成功！\n' >&2
  printf '正在获取订阅信息...\n' >&2

  subscribe_response="$(curl_json "GET" "$SUBSCRIBE_URL" "$authorization" "")" || return 1

  subscribe_url="$(extract_json_string "$subscribe_response" "subscribe_url")"
  if [ -z "$subscribe_url" ]; then
    subscribe_url="$(extract_data_string "$subscribe_response")"
  fi

  if [ -z "$subscribe_url" ]; then
    printf '未能从返回的 JSON 中找到 subscribe_url。\n' >&2
    printf '返回结果: %s\n' "$subscribe_response" >&2
    return 1
  fi

  printf '%s\n' "$subscribe_url"
}

download_config() {
  local url=$(echo "$1"| sed 's/\\//g')
  printf '开始执行下载命令...\n'

  if curl --silent --show-error --fail --insecure --location \
    --max-time 10 \
    --retry 1 \
    --user-agent "$DOWNLOAD_UA" \
    --output "$CONFIG_FILE" \
    "$url"; then
    printf '下载成功！已保存为: %s\n' "$CONFIG_FILE"
    return 0
  fi

  printf '下载失败。\n' >&2
  return 1
}

main() {
  local email
  local password
  local sub_url

  printf '=== 自动订阅下载脚本 ===\n'
  printf '请输入邮箱: '
  IFS= read -r email
  password="$(read_password "请输入密码: ")"

  if [ -z "$email" ] || [ -z "$password" ]; then
    printf '邮箱和密码不能为空！\n' >&2
    return 1
  fi

  sub_url="$(get_subscribe_url "$email" "$password")" || return 1

  printf '%s\n' '------------------------------'
  printf '成功获得订阅链接: %s\n' "$sub_url"
  printf '%s\n' '------------------------------'

  download_config "$sub_url"
}

main "$@"
