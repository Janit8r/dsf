# IPTV Nginx Lua Proxy

自动改写m3u8内容的IPTV反向代理，解决SNAT导致的12.8KB传输限制。

## 架构

- **目标设备**: aarch64_cortex-a53 (QWRT 25.12.2)
- **OpenWrt版本**: ImmortalWrt 24.10.5

## 编译步骤

### 1. GitHub Action自动编译

1. Fork此仓库
2. 启用 Actions
3. 手动触发 `Build nginx-mod-luajit` workflow
4. 等待编译完成（约15-30分钟）
5. 下载 artifacts 中的 `.ipk` 文件

### 2. 手动编译（可选）

```bash
# 下载SDK
wget https://downloads.immortalwrt.org/releases/24.10-SNAPSHOT/targets/ipq60xx/generic/immortalwrt-sdk-24.10-SNAPSHOT-ipq60xx-generic_gcc-14.2.0_musl.Linux-x86_64.tar.xz
tar xf immortalwrt-sdk-*.tar.xz
cd immortalwrt-sdk-*

# 更新feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 编译
make defconfig
make package/nginx-mod-luajit/compile -j$(nproc) V=s

# 查找生成的ipk
find bin/packages -name 'nginx-mod-luajit*.ipk'
```

## 安装

### 1. 上传ipk到路由器

```bash
scp nginx-mod-luajit_*.ipk root@192.168.1.3:/tmp/
scp install.sh root@192.168.1.3:/tmp/
```

### 2. 在路由器上安装

```bash
ssh root@192.168.1.3
cd /tmp
chmod +x install.sh
./install.sh
```

## 使用方法

### VLC播放地址转换

**原地址：**
```
http://116.199.7.27:8006/00000000/1d77ac8593854801b7503a85270ee7b9/index.m3u8
```

**新地址：**
```
http://192.168.1.3:8080/iptv/http://116.199.7.27:8006/00000000/1d77ac8593854801b7503a85270ee7b9/index.m3u8
```

### 工作原理

1. 客户端访问 `http://192.168.1.3:8080/iptv/{原始URL}`
2. Nginx用Lua下载原始m3u8
3. Lua脚本自动替换其中的`http://116.199.x.x`为`http://192.168.1.3:8080/proxy/116.199.x.x`
4. VLC下载TS时自动通过nginx代理
5. Nginx以`192.168.100.2`身份访问IPTV服务器

## 备用方案

如果lua模块编译失败，使用Privoxy HTTP代理：

```bash
opkg install privoxy
# VLC设置HTTP代理: http://192.168.1.3:8118
# 直接播放原始m3u8地址
```

## 故障排查

### 检查nginx是否运行
```bash
ps | grep nginx
netstat -ln | grep 8080
```

### 查看nginx错误日志
```bash
cat /var/log/nginx/error.log
```

### 手动测试m3u8转换
```bash
curl "http://192.168.1.3:8080/iptv/http://116.199.7.27:8006/00000000/xxx/index.m3u8"
```

## 网络拓扑

```
客户端 → 192.168.1.3:8080 (Nginx+Lua)
           ↓ (SNAT to 192.168.100.2)
       116.199.x.x IPTV服务器
```

## 许可证

MIT
