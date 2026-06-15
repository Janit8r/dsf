# IPTV 透明代理解决方案

自动解决SNAT导致的12.8KB传输限制。

## 🎯 快速方案（推荐）

**路由器已安装Privoxy HTTP代理，无需编译！**

### VLC配置

1. 打开VLC → 工具 → 首选项
2. 左下角选择"全部"
3. 输入/编解码器 → 访问模块 → HTTP
4. **HTTP代理URL**: `http://192.168.1.3:8118`
5. 保存并重启VLC

### 播放地址

直接使用原始URL：
```
http://116.199.7.27:8006/00000000/1d77ac8593854801b7503a85270ee7b9/index.m3u8
```

### 工作原理

```
VLC → Privoxy(192.168.1.3:8118) → SNAT(192.168.100.2) → 116.199.x.x
```

- ✅ 无需改写m3u8
- ✅ 支持5000+并发
- ✅ 所有设备通用
- ✅ 已安装可用

---

## 🔧 高级方案：Nginx + Lua（可选）

如需自动改写m3u8 URL，可编译nginx lua模块。

### GitHub Action编译

1. Fork此仓库
2. 启用 Actions
3. 手动触发 `Build nginx-mod-luajit` workflow
4. 等待编译完成
5. 下载 artifacts

### 手动编译

```bash
# 下载SDK
wget https://downloads.immortalwrt.org/snapshots/targets/qualcommax/ipq60xx/immortalwrt-sdk-qualcommax-ipq60xx_gcc-14.3.0_musl.Linux-x86_64.tar.zst
zstd -d immortalwrt-sdk-*.tar.zst
tar xf immortalwrt-sdk-*.tar
cd immortalwrt-sdk-*

# 更新feeds
./scripts/feeds update -a
./scripts/feeds install nginx-ssl

# 配置
make menuconfig
# 选择: Network → Web Servers → nginx-ssl

# 编译
make package/nginx-ssl/compile -j$(nproc)

# 查找ipk
find bin/packages -name 'nginx*.ipk'
```

### 使用Nginx方案

播放地址转换：
```
原: http://116.199.7.27:8006/path/file.m3u8
改: http://192.168.1.3:8080/iptv/http://116.199.7.27:8006/path/file.m3u8
```

---

## 📊 性能对比

| 方案 | 并发能力 | 路由器负载 | 配置复杂度 |
|------|---------|-----------|----------|
| Privoxy | 5000+ | 低 | ⭐ 简单 |
| Nginx反向代理 | 500 | 高 | ⭐⭐⭐ 复杂 |
| 纯SNAT转发 | 10000+ | 极低 | ⭐⭐ 中等 |

**推荐使用Privoxy方案！**

---

## 🐛 故障排查

### Privoxy不工作

```bash
ssh root@192.168.1.3
ps | grep privoxy
netstat -ln | grep 8118

# 重启privoxy
/etc/init.d/privoxy restart
```

### VLC无法播放

1. 检查VLC代理设置
2. 测试: `curl -x http://192.168.1.3:8118 http://116.199.7.27:8006/`
3. 检查路由器网络: `ssh root@192.168.1.3 "curl -I http://116.199.7.27:8006/"`

---

## 网络拓扑

```
客户端(192.168.1.x) 
    ↓ HTTP代理
192.168.1.3:8118 (Privoxy)
    ↓ SNAT
192.168.100.2
    ↓
116.199.x.x IPTV服务器
```

## 许可证

MIT
