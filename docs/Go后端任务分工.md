# Go 后端分工（周子为主导版）

**核心原则**：周子为兜底主线（配置+listener+集成+部署+杂活），张家畅独立模块（测试+repo+明确边界任务）。

## 周子为（主导兜底）- 负责核心流程

### 任务清单：

1. **基础设施全包**

   - 目录结构 `internal/{config,listener,model,verify,api}`
   - `.env` / `.env.example` / `main.go` / `go.mod` 依赖
   - ABI 文件拷贝到 `internal/contracts/`
2. **事件监听主线**

   - `listener/types.go` : ParsedEvent 结构定义
   - `listener/listener.go` : 订阅逻辑（先 mock 后真实）
   - `config/config.go` : 环境变量读取
3. **验证模块**

   - `verify/hash.go` : keccak256 计算与验证
4. **API 与集成**

   - `api/handlers.go` : 所有 HTTP 接口
   - `main.go` : 启动流程（DB+listener+HTTP）
   - 最终演示脚本调试
5. **部署杂活**

   - README.md 启动说明
   - Docker 配置（如需要）
   - 错误处理与日志

**产出判定**：能跑起来，/health 有响应，事件能写入

---

## 张家畅（独立模块）- 测试与存储

### 明确任务边界：

1. **数据库层**

   - `migrations/001_init.sql` : 建表脚本
   - `repository/repository.go` : 纯数据访问层接口与实现
   - DB 连接与迁移执行脚本
2. **单元测试**

   - `repository_test.go` : 数据库操作测试
   - `verify_test.go` : 哈希验证函数测试
   - `integration_test.go` : API 集成测试
   - 测试数据准备与清理
3. **模型定义**

   - `model/models.go` : 数据结构定义（配合 ParsedEvent）

**产出判定**：测试覆盖率 >80%，CI 可跑，repository 接口稳定

---

## 接口契约（一次定死）

```go
// ParsedEvent - 周子为定义，张家畅适配
type ParsedEvent struct {
    TokenID   string
    Author    string  
    DataHash  string
    Block     uint64
    TxHash    string
    LogIndex  uint
    EventName string
}

// Repository - 张家畅实现，周子为调用
type Repository interface {
    InsertResearch(e ParsedEvent) error
    GetByID(id string) (*ResearchData, error)
    ListLatest(limit, offset int) ([]ResearchData, error)
    ListByAuthor(author string, limit, offset int) ([]ResearchData, error)
}

// Verify - 周子为实现，API 调用
func Verify(expected, raw string) bool
```

---

## 合并节点

1. **第1次合并**：基础结构 + repository 接口定义 (12小时内)
2. **第2次合并**：mock 事件流 + 测试框架 (24小时内)
3. **第3次合并**：完整功能 + 演示就绪 (48小时内)

---

## 演示脚本（Final）

```bash
# 1. 启动
./main

# 2. 健康检查
curl localhost:8080/health

# 3. 查看数据 
curl localhost:8080/api/research/latest

# 4. 验证匹配
curl -X POST localhost:8080/api/research/1/verify -d '{"raw":"original data"}'

# 5. 验证不匹配  
curl -X POST localhost:8080/api/research/1/verify -d '{"raw":"modified data"}'
```

---

## 成功标准

- 周子为：系统能启动，事件能监听，API 能响应，演示能跑通
- 张家畅：测试通过，数据层稳定，代码质量合格
- 合并后：端到端流程无阻塞，演示效果达预期
