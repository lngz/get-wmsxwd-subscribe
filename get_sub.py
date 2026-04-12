import urllib.request
import urllib.parse
import json
import http.cookiejar
import subprocess
import getpass

def get_subscribe_url(email, password):
    # 基础 URL 配置
    login_url = "https://api.wmsxwd-3.men/api/v1/passport/auth/login"
    subscribe_url = "https://api.wmsxwd-3.men/api/v1/user/getSubscribe?n=0.543158885715533"
    
    # 准备 Cookie 容器，自动处理会话
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    
    # 设置通用的请求头，模拟浏览器
    headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Content-Type': 'application/json',
        'Accept': 'application/json'
    }

    # 1. 登录
    login_data = json.dumps({
        "email": email,
        "password": password
    }).encode('utf-8')

    print(f"\n正在尝试登录用户: {email}...")
    
    try:
        req_login = urllib.request.Request(login_url, data=login_data, headers=headers, method='POST')
        with opener.open(req_login) as response:
            login_res = json.loads(response.read().decode('utf-8'))
            
            # 检查登录是否成功
            if not login_res.get('data'):
                print("登录失败，请检查账号密码或网站状态。")
                print("返回信息:", login_res)
                return None
            
            # 获取授权令牌
            auth_token = login_res.get('data')
            if isinstance(auth_token, str):
                headers['Authorization'] = auth_token
            elif isinstance(auth_token, dict) and 'auth_data' in auth_token:
                headers['Authorization'] = auth_token['auth_data']
            elif isinstance(auth_token, dict) and 'token' in auth_token:
                headers['Authorization'] = auth_token['token']
                
            print("登录成功！")

        # 2. 获取订阅链接
        print("正在获取订阅信息...")
        req_sub = urllib.request.Request(subscribe_url, headers=headers, method='GET')
        with opener.open(req_sub) as response:
            sub_res = json.loads(response.read().decode('utf-8'))
            
            # 提取 subscribe_url
            data = sub_res.get('data')
            if data and isinstance(data, dict) and 'subscribe_url' in data:
                return data['subscribe_url']
            elif isinstance(data, str):
                return data
            else:
                print("未能从返回的 JSON 中找到 subscribe_url。")
                print("返回结果:", sub_res)
                return None

    except Exception as e:
        print(f"发生错误: {e}")
        return None

def download_config(url):
    print("开始执行下载命令...")
    # 构造你提供的 curl 命令
    curl_cmd = [
        "curl",
        "--silent",
        "--show-error",
        "--fail",
        "--insecure",
        "--location",
        "--max-time", "10",
        "--retry", "1",
        "--user-agent", "clash-verge/v2.4.0",
        "--output", "config.yaml",
        url
    ]
    
    try:
        # 执行命令
        subprocess.run(curl_cmd, check=True)
        print("下载成功！已保存为: config.yaml")
        return True
    except subprocess.CalledProcessError as e:
        print(f"下载失败 (curl 报错): {e}")
        return False
    except Exception as e:
        print(f"执行命令时发生意外错误: {e}")
        return False

if __name__ == "__main__":
    print("=== 自动订阅下载脚本 ===")
    try:
        my_email = input("请输入邮箱: ").strip()
        my_password = getpass.getpass("请输入密码: ")
        
        if not my_email or not my_password:
            print("邮箱和密码不能为空！")
        else:
            sub_url = get_subscribe_url(my_email, my_password)
            if sub_url:
                print("-" * 30)
                print(f"成功获得订阅链接: {sub_url}")
                print("-" * 30)
                
                # 执行下载
                download_config(sub_url)
    except KeyboardInterrupt:
        print("\n操作已取消。")
