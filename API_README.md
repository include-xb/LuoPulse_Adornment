# lpserver

LuoPulse 基于 OpenList 的文件下载直链与 SHA256 校验 API。

- 文件管理与传输全部经由服务器端 OpenList 完成。
- 本地存储挂载在 OpenList 根路径 `/`，磁盘目录为 `/home/user000/openlist`。
- 当前仅开放模块 `sympathy`，对应 OpenList 路径 `/SongPackages/Sympathy`。
- 只扫描模块目录下的顶层文件，不递归子目录。
- 鉴权使用单个 API Key，支持 `X-API-Key` 和 `Authorization: Bearer`。

## 目录

- [快速开始](#快速开始)
- [配置说明](#配置说明)
- [鉴权](#鉴权)
- [API 说明](#api-说明)
- [SHA256 计算与缓存](#sha256-计算与缓存)
- [下载链接说明](#下载链接说明)
- [部署](#部署)
- [运维](#运维)
- [新增模块](#新增模块)
- [开发与测试](#开发与测试)
- [常见问题](#常见问题)
- [安全建议](#安全建议)

## 快速开始

要求 Node.js >= 20.11。

```bash
npm ci

# 创建配置文件
cp .env.example .env
# Windows cmd 使用：copy .env.example .env

# 生成 API Key，并写入 .env 的 API_KEY
node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
```

编辑 `.env`，至少填写：

```dotenv
API_KEY=<上面生成的key>
OPENLIST_BASE_URL=http://127.0.0.1:5244
OPENLIST_USERNAME=admin
OPENLIST_PASSWORD=<OpenList管理员密码>
OPENLIST_BASE_PATH=/
OPENLIST_LOCAL_ROOT=/home/user000/openlist
```

如果 OpenList 管理员启用了两步验证，或者不想使用账号密码登录，可以改用全局 API Token：

```dotenv
OPENLIST_TOKEN=<OpenList全局API Token>
```

启动开发服务：

```bash
npm run dev
```

服务默认监听 `127.0.0.1:3000`。生产环境使用：

```bash
npm run build
npm start
```

检查是否启动成功：

```bash
curl http://127.0.0.1:3000/healthz
# {"status":"ok"}
```

## 配置说明

配置文件为项目根目录的 `.env`，所有变量如下。

| 变量 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `PORT` | 否 | `3000` | HTTP 监听端口 |
| `HOST` | 否 | `127.0.0.1` | 监听地址；使用 Nginx 反代时保持默认 |
| `API_KEY` | 是 | 无 | 客户端鉴权 Key，长度至少 32 字符 |
| `OPENLIST_BASE_URL` | 是 | 无 | OpenList 地址，例如 `http://127.0.0.1:5244` |
| `OPENLIST_USERNAME` | 条件必填 | 无 | OpenList 用户名；未设置 Token 时必填 |
| `OPENLIST_PASSWORD` | 条件必填 | 无 | OpenList 密码；未设置 Token 时必填 |
| `OPENLIST_TOKEN` | 否 | 无 | OpenList 全局 API Token；设置后跳过账号密码登录 |
| `OPENLIST_BASE_PATH` | 否 | `/` | local 存储在 OpenList 中的挂载路径 |
| `OPENLIST_LOCAL_ROOT` | 否 | `/home/user000/openlist` | 该挂载对应的磁盘根目录 |
| `OPENLIST_PUBLIC_URL` | 否 | 无 | 生成下载链接时使用的 OpenList 公网地址；优先级最高 |
| `OPENLIST_TIMEOUT_MS` | 否 | `15000` | 单次调用 OpenList 的超时时间 |
| `HASH_CACHE_PATH` | 否 | `./data/hash-cache.json` | SHA256 缓存文件路径 |
| `SHA256_CONCURRENCY` | 否 | `2` | 本地计算 SHA256 的并发数 |

### 获取 OpenList 全局 API Token

登录 OpenList 管理后台，进入 **设置 → 其他 → 令牌（API Token）**，复制显示的 Token。

也可以在服务器上通过 CLI 获取：

```bash
# 二进制部署
cd /opt/openlist && ./openlist admin token

# Docker 部署（容器名按实际情况修改）
docker exec -it openlist ./openlist admin token
```

1Panel 用户可以打开 **容器 → OpenList → 终端**，进入 OpenList 安装目录后执行：

```bash
./openlist admin token
```

注意：

- 在 OpenList 后台“重置”令牌会立即让旧 Token 失效，所有使用旧 Token 的服务都要同步更新并重启。
- 全局 API Token 拥有管理员级 API 权限，请只保存在服务器的 `.env` 中，不要提交或发送给第三方。

### 路径映射

`OPENLIST_BASE_PATH` 与 `OPENLIST_LOCAL_ROOT` 必须对应同一个存储挂载：

| OpenList 挂载路径 | 模块在 OpenList 中的路径 | 磁盘路径 |
| --- | --- | --- |
| `/` | `/SongPackages/Sympathy` | `/home/user000/openlist/SongPackages/Sympathy` |
| `/local` | `/local/SongPackages/Sympathy` | `/home/user000/openlist/SongPackages/Sympathy` |

如果配置了 `/local` 挂载，请设置：

```dotenv
OPENLIST_BASE_PATH=/local
OPENLIST_LOCAL_ROOT=/home/user000/openlist
```

服务会先去掉 `/local` 前缀，再映射到磁盘目录。

### 下载地址来源

下载链接按以下优先级确定基础地址：

1. `OPENLIST_PUBLIC_URL`
2. OpenList `/api/public/settings` 返回的 `site_url`
3. `OPENLIST_BASE_URL`

如果 OpenList 部署在域名后，建议显式设置 `OPENLIST_PUBLIC_URL`，否则可能返回 `http://127.0.0.1:5244/...` 这种客户端无法访问的链接。

## 鉴权

除 `/healthz` 外，所有接口都需要 API Key。任选一种方式：

```http
X-API-Key: <API_KEY>
```

```http
Authorization: Bearer <API_KEY>
```

鉴权失败返回：

```http
HTTP/1.1 401 Unauthorized
Content-Type: application/json

{
  "error": "unauthorized",
  "message": "missing or invalid API key"
}
```

服务日志默认会对 `authorization` 和 `x-api-key` 请求头做脱敏。

## API 说明

端点: https://lpserver.thirhythm.top

### 获取模块文件下载链接

```http
GET /api/download?module=sympathy
X-API-Key: <API_KEY>
```

`module` 为必填参数，当前合法值只有 `sympathy`。

响应：

```json
{
  "module": "sympathy",
  "files": [
    {
      "name": "a.zip",
      "path": "SongPackages/Sympathy/a.zip",
      "size": 123456,
      "modified": "2026-01-01T00:00:00Z",
      "url": "https://openlist.example.com/d/SongPackages/Sympathy/a.zip?sign=..."
    }
  ]
}
```

字段说明：

| 字段 | 说明 |
| --- | --- |
| `module` | 请求的模块名 |
| `files` | 顶层文件列表，按 `name` 升序排列 |
| `name` | 文件名 |
| `path` | OpenList 内完整路径（不含开头 `/`） |
| `size` | 文件大小（字节） |
| `modified` | OpenList 返回的修改时间；为空时是空字符串 |
| `url` | OpenList 下载直链；OpenList 返回 sign 时自动追加 `?sign=` |

示例：

```bash
curl -H "X-API-Key: $API_KEY" \
  "http://127.0.0.1:3000/api/download?module=sympathy"
```

客户端拿到 `url` 后直接向 OpenList 下载，本服务不代理文件流量。

### 获取模块文件 SHA256

```http
GET /api/sha256?module=sympathy
Authorization: Bearer <API_KEY>
```

响应：

```json
{
  "module": "sympathy",
  "files": [
    {
      "name": "a.zip",
      "path": "SongPackages/Sympathy/a.zip",
      "size": 123456,
      "modified": "2026-01-01T00:00:00Z",
      "sha256": "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
    }
  ]
}
```

示例：

```bash
curl -H "X-API-Key: $API_KEY" \
  "http://127.0.0.1:3000/api/sha256?module=sympathy"
```

该接口返回该目录全部顶层文件的 SHA256。任意一个文件计算失败时，整个请求返回 502，不会返回部分结果，避免客户端拿到不完整的校验清单。

### 健康检查

```http
GET /healthz
```

无需鉴权，返回：

```json
{"status":"ok"}
```

### 错误响应

错误统一返回：

```json
{
  "error": "invalid_module",
  "message": "invalid module 'other'; valid values: sympathy"
}
```

| HTTP 状态 | `error` | 说明 |
| --- | --- | --- |
| 400 | `invalid_module` | `module` 缺失或不在白名单 |
| 401 | `unauthorized` | API Key 缺失或错误 |
| 404 | `not_found` | 模块目录在 OpenList 中不存在 |
| 502 | `openlist_error` | OpenList 不可达、登录失败或接口返回错误 |
| 502 | `hash_failed` | `hash_info` 缺失且本地文件无法读取或大小发生变化 |
| 500 | `internal_error` | 服务内部错误 |

## SHA256 计算与缓存

单个文件的 SHA256 按以下顺序获取：

1. 本地持久化缓存：命中 `路径 + 大小 + 修改时间` 时直接返回。
2. OpenList 返回的 `hash_info` / `hashinfo` 中的 `sha256`。
3. 从 `OPENLIST_LOCAL_ROOT` 映射到磁盘，以流式读取方式计算 SHA256。

文件大小或修改时间变化后，旧缓存自动失效并重新计算。每次成功返回 SHA256 后，服务会清理该模块中已删除文件的缓存并写回磁盘。

相关配置：

```dotenv
HASH_CACHE_PATH=./data/hash-cache.json
SHA256_CONCURRENCY=2
```

注意事项：

- 首次请求需要计算全部未缓存文件，大文件可能耗时较长。
- 服务已关闭 Node 的请求超时；Nginx 示例配置将读写超时设为 1800 秒。如果文件特别大，可继续调大。
- 缓存目录必须可写；systemd 配置假设为 `/opt/lpserver/data`。
- 本地计算要求运行服务的用户对 `/home/user000/openlist` 有读权限。

## 下载链接说明

- 下载链接格式为 `{OpenList 基础地址}/d/{URL 编码后的路径}`。
- OpenList 返回 `sign` 时会追加 `?sign=...`。
- 本服务只保护“获取链接”这个动作；链接一旦被客户端拿到，持有链接的人即可直接访问 OpenList。若需要更严格的访问控制，请在 OpenList 侧启用签名、认证或访问限制。
- 文件名中的空格、`#`、中文等会被正确 URL 编码。

## 部署

以下步骤假设：

- 项目部署在 `/opt/lpserver`
- 服务用户为 `user000`
- Node 位于 `/usr/bin/node`
- OpenList 与本服务在同一台服务器

请根据实际情况调整路径和用户。

### 1. 构建

```bash
cd /opt/lpserver
npm ci
npm run build
mkdir -p data
chown -R user000:user000 /opt/lpserver
```

确认 `user000` 能读取 OpenList 文件：

```bash
sudo -u user000 test -r /home/user000/openlist/SongPackages/Sympathy && echo readable
```

### 2. 配置

编辑 `/opt/lpserver/.env`，填写 OpenList 密码或 Token，并按需设置 `OPENLIST_PUBLIC_URL`。

建议收紧配置文件权限：

```bash
chmod 600 /opt/lpserver/.env
```

### 3. systemd

```bash
cp deploy/lpserver.service /etc/systemd/system/lpserver.service
systemctl daemon-reload
systemctl enable --now lpserver
systemctl status lpserver
```

查看日志：

```bash
journalctl -u lpserver -f
```

### 4. Nginx

```bash
cp deploy/nginx-lpserver.conf /etc/nginx/conf.d/lpserver.conf
nginx -t
systemctl reload nginx
```

需要修改：

- `server_name`
- HTTPS 证书路径，并启用 `listen 443 ssl http2`
- 如果使用非默认端口或地址，调整 `proxy_pass`

Nginx 示例只允许 `GET` 访问 `/api/`，并为 SHA256 首次计算保留了较长的超时时间。

### 5. 验证

```bash
curl -H "X-API-Key: <API_KEY>" \
  "https://api.example.com/api/download?module=sympathy"

curl -H "X-API-Key: <API_KEY>" \
  "https://api.example.com/api/sha256?module=sympathy"
```

### 在 1Panel 面板上安装 Node.js

1Panel 有两种方式。按本项目的 systemd 部署方案，推荐方式一。

#### 方式一：在宿主机安装（推荐，适配 systemd）

1. 打开 1Panel → 主机 → 终端，或直接 SSH 登录服务器。
2. 确认系统类型：

```bash
cat /etc/os-release
```

3. Ubuntu / Debian：

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
```

Rocky / AlmaLinux / CentOS Stream / Fedora：

```bash
curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
sudo dnf install -y nodejs
```

4. 验证：

```bash
node -v    # 需要 >= 20.11，推荐 22.x LTS
npm -v
which node
```

5. 如果 `which node` 不是 `/usr/bin/node`，把 `deploy/lpserver.service` 中的 `ExecStart` 改成实际路径。
6. 之后按上一节完成构建与 systemd 配置。

不建议用 nvm 安装后再配 systemd：nvm 的 Node 只对当前 shell 生效，systemd 默认找不到。若坚持使用 nvm，需要在 unit 中写 Node 的绝对路径并显式设置环境变量。

#### 方式二：使用 1Panel 的 Node.js 运行环境（容器化）

1Panel → 运行环境 → Node.js 运行环境 → 创建，选择 22 LTS。

注意这种方式本质是容器，不是宿主机安装：

- 启动命令示例：`npm ci && npm run build && node dist/index.js`
- 需要把 `/home/user000/openlist` 挂载进容器，并把 `OPENLIST_LOCAL_ROOT` 改成容器内路径。
- 容器内的 `127.0.0.1` 不是宿主机，`OPENLIST_BASE_URL` 必须改成容器可访问的地址，例如同一 Docker 网络中的 OpenList 服务名，或 `host.docker.internal`（需配置 host-gateway）。
- 该方式不使用 systemd，由 1Panel 管理容器，`deploy/lpserver.service` 不再适用。

本项目推荐方式一：SHA256 本地兜底需要直接读取宿主机文件，OpenList 通过 `127.0.0.1:5244` 访问也最省事。

#### 在 1Panel 中配置反向代理

1Panel 的 OpenResty 配置由面板统一管理。不要把 `deploy/nginx-lpserver.conf` 直接复制到 `/etc/nginx/conf.d/`，该目录可能不在 1Panel OpenResty 的 include 路径中。

推荐步骤：

1. 1Panel → 网站 → 创建网站 → 反向代理。
2. 域名填写你的域名；如果暂时用 IP 访问，填写服务器 IP，或先创建一个域名站点。
3. 代理地址填写 `http://127.0.0.1:3000`。
4. 保存后，1Panel 会自动生成配置并重载 OpenResty。

说明：

- 通过 IP 访问出现 OpenResty 的 404，通常是没有匹配到站点（`server_name` 不匹配），不是 lpserver 返回的。
- 如果使用域名，可以用 `curl -H "Host: 你的域名" http://服务器IP/healthz` 测试。
- 如果改成反向代理后出现 502，说明 OpenResty 无法访问 `127.0.0.1:3000`。确认 lpserver 正在监听，并检查 OpenResty 是否为容器网络；容器内访问宿主机可用 `host.docker.internal` 或宿主机网关地址。
- 反向代理的超时时间需要在 1Panel 站点配置中调大，否则首次 SHA256 计算可能被截断。

## 运维

### 更换 API Key

1. 修改 `.env` 中的 `API_KEY`。
2. 重启服务：

```bash
systemctl restart lpserver
```

3. 通知所有客户端更新 Key。

### 清空 SHA256 缓存

```bash
systemctl stop lpserver
rm -f /opt/lpserver/data/hash-cache.json
systemctl start lpserver
```

下次请求会重新计算并生成缓存。也可以在服务运行时只删除单个条目，但需要先停止服务避免覆盖。

### 更新代码

```bash
cd /opt/lpserver
npm ci
npm run build
systemctl restart lpserver
```

## 新增模块

模块白名单定义在 `src/modules.ts`：

```ts
export const MODULES = {
  sympathy: { openlistPath: "SongPackages/Sympathy" },
  // 新增模块示例
  another: { openlistPath: "SongPackages/Another" },
} as const satisfies Readonly<Record<string, ModuleDefinition>>;
```

修改后重新构建并重启：

```bash
npm run build
systemctl restart lpserver
```

之后即可调用：

```http
GET /api/download?module=another
GET /api/sha256?module=another
```

`openlistPath` 相对于 `OPENLIST_BASE_PATH` 解析，不需要写开头的 `/`。

## 开发与测试

```bash
npm run typecheck   # TypeScript 类型检查
npm test            # 运行测试（使用 mock OpenList，不依赖真实实例）
npm run build       # 编译到 dist/
npm run dev         # 开发模式，自动重载
```

测试覆盖：

- OpenList 登录、Token 过期重登、分页
- `/d/` 链接编码与 sign
- API Key 鉴权
- 模块白名单
- SHA256 的 `hash_info` 优先、本地兜底、缓存复用
- 目录映射与路径安全

## 常见问题

### 返回 401

确认请求头名称和值：

```bash
curl -v -H "X-API-Key: $API_KEY" ...
```

也确认修改 `.env` 后已经重启服务。

### 返回 502 `openlist_error`

按顺序检查：

1. `OPENLIST_BASE_URL` 是否可从本机访问。
2. 如果 OpenList 由 1Panel 以容器方式运行，确认容器端口已映射到宿主机 `127.0.0.1:5244`（1Panel → 容器 → 端口）。
3. OpenList 账号密码是否正确。
3. OpenList 管理员是否启用了两步验证。启用 2FA 时建议改用 `OPENLIST_TOKEN`。
4. OpenList 日志中是否有登录失败或路径不存在。

### 返回 404 `not_found`

检查 OpenList 中是否真的存在对应目录：

- `OPENLIST_BASE_PATH=/` 时，目录应为 `/SongPackages/Sympathy`。
- 如果 local 存储挂载在 `/local`，应设置 `OPENLIST_BASE_PATH=/local`，目录为 `/local/SongPackages/Sympathy`。

### 下载链接是 127.0.0.1

说明 OpenList 的 `site_url` 为空或本服务回退到了 `OPENLIST_BASE_URL`。设置：

```dotenv
OPENLIST_PUBLIC_URL=https://你的OpenList公网地址
```

然后重启服务。

### 返回 502 `hash_failed`

常见原因：

- 服务用户没有 `/home/user000/openlist` 的读权限。
- `OPENLIST_LOCAL_ROOT` 配置错误。
- 文件在 OpenList 列出后、读取前被修改或删除。

检查：

```bash
sudo -u user000 ls -l /home/user000/openlist/SongPackages/Sympathy
```

### 首次 SHA256 请求很慢或 Nginx 504

首次需要读取全部文件计算哈希。可以：

- 增大 Nginx 的 `proxy_read_timeout` 和 `proxy_send_timeout`。
- 适当提高 `SHA256_CONCURRENCY`，但注意磁盘 IO。
- 错峰或预热请求。

缓存生成后，后续请求会很快返回。

### 服务启动时报 `API_KEY must be at least 32 characters`

说明 `.env` 中的 `API_KEY` 为空、仍是 `.env.example` 的占位符 `replace-with-64-hex-chars`，或长度不足 32 字符。

```bash
cd /opt/lpserver
KEY=$(node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))")
sed -i "s|^API_KEY=.*|API_KEY=$KEY|" .env
grep '^API_KEY=' .env | awk -F= '{print "API_KEY length:", length($2)}'
```

修改后重启服务。注意 `.env` 已被 `.gitignore` 排除，上传代码时不会自动带上，需要在服务器上单独创建或配置。

### 服务启动时报缺少环境变量

按 `.env.example` 检查必填项：

- `API_KEY`
- `OPENLIST_BASE_URL`
- `OPENLIST_TOKEN` 或 `OPENLIST_USERNAME` + `OPENLIST_PASSWORD`

`API_KEY` 至少 32 个字符。

## 安全建议

- `.env` 已被 `.gitignore` 排除，不要提交或公开。
- 生产环境务必使用 HTTPS。
- 定期轮换 API Key。
- 服务默认只监听 `127.0.0.1`，不要直接暴露 Node 端口，统一走 Nginx。
- 如需进一步限制来源，可在 Nginx 中配置 `allow` / `deny`。
- 下载直链本身不经过本服务鉴权，若文件敏感，请在 OpenList 侧启用签名或访问控制。
- SHA256 缓存目录只允许服务用户读写。
