#!/bin/sh
# 在OpenWrt路由器上运行此脚本

echo "=== IPTV Nginx Lua代理安装脚本 ==="

# 1. 上传编译好的ipk文件到/tmp
echo "请先上传以下文件到 /tmp/："
echo "  - nginx-mod-luajit_*.ipk"
echo "  - lua-resty-http_*.ipk (如果需要)"
echo ""
read -p "已上传？按回车继续..."

# 2. 安装ipk
echo ""
echo "=== 安装nginx-mod-luajit ==="
opkg install /tmp/nginx-mod-luajit_*.ipk

# 3. 安装lua-resty-http
echo ""
echo "=== 安装lua-resty-http ==="
opkg update
opkg install lua-resty-http || echo "手动安装..."

# 4. 配置nginx
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
    
    lua_package_path "/usr/lib/lua/?.lua;;";
    
    include /etc/nginx/conf.d/*.conf;
}
MAIN

mkdir -p /etc/nginx/conf.d

cat > /etc/nginx/conf.d/iptv.conf << 'IPTV'
server {
    listen 8080;
    
    resolver 8.8.8.8;
    
    # m3u8入口
    location ~ ^/iptv/(.+)$ {
        set $original_url $1;
        content_by_lua_block {
            -- 解码URL
            local url = ngx.var.original_url
            url = ngx.unescape_uri(url)
            
            -- 下载原始m3u8
            local handle = io.popen("curl -s '" .. url .. "'")
            local content = handle:read("*a")
            handle:close()
            
            -- 替换链接
            content = string.gsub(content, "http://116%.199%.", "http://192.168.1.3:8080/proxy/116.199.")
            
            ngx.header["Content-Type"] = "application/vnd.apple.mpegurl"
            ngx.say(content)
        }
    }
    
    # TS代理
    location ~ ^/proxy/(.+):(\d+)/(.*)$ {
        set $target_host $1;
        set $target_port $2;
        set $target_path $3;
        
        proxy_pass http://$target_host:$target_port/$target_path$is_args$args;
        proxy_buffering off;
        proxy_set_header Host $target_host:$target_port;
        proxy_http_version 1.1;
    }
}
IPTV

# 5. 重启nginx
echo ""
echo "=== 重启nginx ==="
killall nginx
sleep 1
/usr/sbin/nginx -c /etc/nginx/nginx.conf

echo ""
echo "=== 测试 ==="
sleep 2
curl -I http://192.168.1.3:8080/iptv/http://116.199.7.27:8006/00000000/test.m3u8

echo ""
echo "✅ 安装完成！"
echo ""
echo "【使用方法】"
echo "VLC播放地址："
echo "http://192.168.1.3:8080/iptv/http://116.199.7.27:8006/00000000/xxx/index.m3u8"
