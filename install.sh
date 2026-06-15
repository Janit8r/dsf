#!/bin/sh
# 在OpenWrt路由器上运行此脚本

echo "=== IPTV Nginx+Lua代理安装脚本 ==="

# 1. 检查ipk文件
echo "检查ipk文件..."
ls -lh /tmp/*.ipk 2>/dev/null || echo "请先上传ipk文件到/tmp/"

# 2. 安装nginx和lua
echo ""
echo "=== 安装nginx-ssl ==="
opkg install /tmp/nginx*.ipk

echo ""
echo "=== 安装lua依赖 ==="
opkg install /tmp/lua*.ipk || opkg install lua luajit

# 3. 配置nginx
echo ""
echo "=== 配置nginx ==="

cat > /etc/nginx/nginx.conf << 'MAIN'
user root;
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    sendfile on;
    keepalive_timeout 65;
    
    include /etc/nginx/conf.d/*.conf;
}
MAIN

mkdir -p /etc/nginx/conf.d

cat > /etc/nginx/conf.d/iptv.conf << 'IPTV'
server {
    listen 8080;
    
    resolver 8.8.8.8;
    
    # m3u8入口：下载并改写URL
    location ~ ^/iptv/(.+)$ {
        default_type application/vnd.apple.mpegurl;
        
        content_by_lua_block {
            -- 获取原始URL
            local original_url = ngx.var[1]
            original_url = ngx.unescape_uri(original_url)
            
            -- 下载原始m3u8
            local handle = io.popen("curl -s '" .. original_url .. "'")
            local content = handle:read("*a")
            handle:close()
            
            -- 替换所有116.199链接
            content = string.gsub(content, "http://116%.199%.", "http://192.168.1.3:8080/proxy/116.199.")
            
            -- 返回
            ngx.say(content)
        }
    }
    
    # TS文件代理
    location ~ ^/proxy/(.+):(\d+)/(.*)$ {
        set $target_host $1;
        set $target_port $2;
        set $target_path $3;
        
        proxy_pass http://$target_host:$target_port/$target_path$is_args$args;
        proxy_buffering off;
        proxy_set_header Host $target_host:$target_port;
        proxy_http_version 1.1;
        proxy_connect_timeout 10s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
IPTV

# 4. 设置开机自启
cat > /etc/init.d/nginx_iptv << 'INIT'
#!/bin/sh /etc/rc.common
START=99

start() {
    /usr/sbin/nginx -c /etc/nginx/nginx.conf
}

stop() {
    killall nginx
}

restart() {
    stop
    sleep 1
    start
}
INIT

chmod +x /etc/init.d/nginx_iptv
/etc/init.d/nginx_iptv enable

# 5. 启动nginx
echo ""
echo "=== 启动nginx ==="
killall nginx 2>/dev/null
sleep 1
/usr/sbin/nginx -c /etc/nginx/nginx.conf

echo ""
echo "=== 检查状态 ==="
ps | grep nginx | grep -v grep
netstat -ln | grep 8080

echo ""
echo "=== 测试 ==="
sleep 2
curl -I "http://192.168.1.3:8080/iptv/http://116.199.7.27:8006/00000000/test.m3u8" 2>&1 | head -5

echo ""
echo "✅ 安装完成！"
echo ""
echo "【VLC使用方法】"
echo "原地址: http://116.199.7.27:8006/00000000/xxx/index.m3u8"
echo "新地址: http://192.168.1.3:8080/iptv/http://116.199.7.27:8006/00000000/xxx/index.m3u8"
echo ""
echo "所有链接会自动改写，无需手动转换TS地址！"

