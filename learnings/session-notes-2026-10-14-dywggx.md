

## 前置条件
- 检查
```shell
node --version
npm --version
git --version
```
- 建议结果  
```shell
Node.js: v22.16.0 或更高
npm:     正常输出版本
Git:     正常输出版本
```

## 安装

- 检查有哪些可安装版本  
```shell
npm view @rpamis/comet versions
```
- 安装指定版本
```shell
npm install -g @rpamis/comet@0.4.3
```
- 验证安装结果
```shell
npm list -g @rpamis/comet --depth=0
comet --version
```


### 升级
```shell
npm install -g @rpamis/comet@latest
```

### 卸载 
```shell
npm uninstall -g @rpamis/comet
```
   

## 初始化项目
- 初始化
```shell
cd <your_project>

comet init --workflow classic

```
- 选择配置项
```shell

           ██████╗ ██████╗ ███╗   ███╗███████╗████████╗
          ██╔════╝██╔═══██╗████╗ ████║██╔════╝╚══██╔══╝
          ██║     ██║   ██║██╔████╔██║█████╗     ██║
          ██║     ██║   ██║██║╚██╔╝██║██╔══╝     ██║
          ╚██████╗╚██████╔╝██║ ╚═╝ ██║███████╗   ██║
           ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝   ╚═╝
  Agent Skill Harness For Turning Ideas Into Evaluated Workflows

  Comet v0.4.3
  New version v0.4.4 available. Run 'npm update -g @rpamis/comet' to upgrade.
✔ Language for Comet skills: 中文
  正在设置 Comet： D:\tfs\mkcollection\code\e-commerce-domainservices\cms-product-services

✔ 安装范围： 项目（当前目录）
✔ 安装模式： Copy（传统方式，每个平台独立副本）
✔ 选择要配置的平台： GitHub Copilot
✔ GitHub Copilot 已安装 OpenSpec, Comet. 如何处理？ 覆盖所有已有组件
(node:18660) [DEP0190] DeprecationWarning: Passing args to a child process with shell option true can lead to security vulnerabilities, as the arguments are not escaped, only concatenated.
(Use `node --trace-deprecation ...` to show where the warning was created)
✔ 选择要安装/升级的 npm 依赖： OpenSpec CLI（已全局安装 — 升级到最新版本）, Superpowers (npx skills add obra/superpowers), Code
Graph CLI（已安装 — 升级到最新版本）

  正在安装 OpenSpec： github-copilot
    Upgrading OpenSpec CLI...
```

### 注意:
> 如果有github报错, 请使用proxy后再执行






- 推荐配置项 .comet\config.yaml
```yaml
# Comet 使用的配置格式版本，请勿修改此值。
schema: comet.project.v1
# `/comet` 默认进入的工作流；该值也必须出现在 workflows 中。
default_workflow: classic
# 此项目启用的工作流，可填写 native、classic 或同时启用两者。
workflows:
  - classic
# 是否启用只读的环境感知恢复探针，同时作用于 Native 和 Classic；设为 false 可关闭自动工作流恢复。
# ambient_resume: true | false
ambient_resume: true
# 当前项目的个人记忆自动学习与注入策略。
memory:
  # 是否允许当前项目通过工作流事件自动沉淀新的个人记忆。
  # 可选值：true | false
  learning: true
  # 是否允许当前项目把个人记忆自动注入 Agent 上下文。
  # 可选值：true | false
  retrieval: true
# 普通 Comet 任务使用的项目知识检索 Provider。
knowledge:
  # 项目知识 Provider。
  # 可选值：local | remote
  provider: local
# Classic 工作流配置，不会改变 Native 的状态或行为。
classic:
  # Classic 产物布局；默认使用 docs，update 检测到根目录 legacy 产物时予以保留。
  # 可选值：legacy | docs
  artifact_layout: docs
  # Classic 工作流文档使用的产物语言。
  # 可选值：en | zh-CN
  language: zh-CN
  # 新建 Classic change 是否启用 beta 上下文压缩。
  # 可选值：off | beta
  context_compression: off
  # 新建 Classic change 默认使用的审查深度。
  # 可选值：off | standard | thorough
  review_mode: thorough
  # Classic 阶段通过后是否自动进入下一阶段。
  # 可选值：true | false
  auto_transition: false

```











## [可选] 手动安装 codegraph
### 全局安装
```shell
npm install -g @colbymchenry/codegraph
codegraph install
```

### 初始化 CodeGraph 项目索引
- 初始化
```shell
cd <your_project>

comet init --workflow classic

```

#### 注意:
> 不要手工编辑这些数据库文件

### 检查索引状态
```shell
codegraph status
```
- 输出
```shell
PS D:\tfs\mkcollection\code\e-commerce-domainservices\cms-product-services> codegraph status

CodeGraph Status

Project: D:\tfs\mkcollection\code\e-commerce-domainservices\cms-product-services

Index Statistics:
  Files:     37
  Nodes:     445
  Edges:     857
  DB Size:   1.38 MB
  Backend:   node:sqlite — built-in (full WAL)
  Journal:   wal

Nodes by Kind:
  import          106
  method          105
  struct          60
  constant        55
  function        43
  route           32
  file            29
  variable        9
  interface       6

Files by Language:
  go              27
  yaml            5
  properties      3
  javascript      1
  python          1

✓ Index is up to date
```


### 验证codegraph mcp 是否可用

- 打开 copilot ,在agent中输入
```text
列出当前会话可用的 MCP 工具，并确认是否存在 CodeGraph。
```
- 反馈结果
```shell
Checking my documentation  # GitHub Copilot CLI Documentation

Thought for 1s

codegraph_explore (MCP: codegraph) · repository index status · query: "repository index status" **Exploration: repository index status**

Thought for 6s

当前会话可用的代码与数据集成工具：

•  codegraph-codegraph_explore  — CodeGraph 代码索引与符号探索
•  lexical_code_search  — GitHub 代码搜索
•  session_store_sql  — 查询跨会话历史
•  web_fetch  — 获取网页内容

CodeGraph 存在且可用：刚才的探索成功返回索引结果（82 个符号，涉及 2 个文件）。当前工具列表中没有显式提供 GitHub MCP 的 PR、Issue 等操作工具。
```


