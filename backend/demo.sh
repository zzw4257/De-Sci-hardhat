#!/bin/bash

#!/bin/bash

# 进入backend目录
cd /Users/zzw4257/Documents/ZJU_archieve/05.课程与学术资料/区块链/重来/backend

# 运行演示服务器
echo "� Starting DeSci Backend Demo Server..."
echo "� Working directory: $(pwd)"
echo "� Available files:"
ls -la cmd/server/

# 启动服务器
go run cmd/server/main_demo.go