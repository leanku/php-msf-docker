#!/bin/bash

# 验证 protoc、gRPC 和 absl 安装的 Shell 脚本
# 使用方法：./check_install.sh

set -e  # 如果任何命令失败，则退出脚本
echo -e "=== 系统信息 ==="
cat /etc/os-release

echo -e "\n=== dnf installed 列表 ==="
dnf list installed

echo -e "\n=== 开始验证 nginx、redis 和 php 安装 ==="

echo -e "\n[1/3] 验证 nginx 安装..."
nginx -v
echo "✓ nginx 版本检查通过"

echo -e "\n[2/3] 验证 redis 安装..."
redis --version
echo "✓ redis 版本检查通过"

echo -e "\n[3/3] 验证 php 安装..."
php -v
echo "✓ php 版本检查通过"

echo -e "\n=== nginx、redis 和 php 安装验证成功 ==="

echo -e "\n=== 已安装的php 扩展: ==="
php -m


# ===
echo -e "\n=== 开始验证 protoc、gRPC 和 Abseil (absl) 安装 ==="

# 1. 验证 protoc 安装
echo -e "\n[1/3] 验证 protoc 安装..."
protoc --version
echo "✓ protoc 版本检查通过"

# 创建测试 proto 文件
echo 'syntax = "proto3"; message TestMsg { string test = 1; }' > test.proto

# 编译 proto 文件
protoc --cpp_out=. test.proto

if [[ -f "test.pb.cc" && -f "test.pb.h" ]]; then
    echo "✓ protoc 编译测试通过"
    rm test.pb.cc test.pb.h test.proto
else
    echo "✗ protoc 编译测试失败"
    exit 1
fi

# 2. 验证 gRPC 安装
echo -e "\n[2/3] 验证 gRPC 安装..."
GRPC_PLUGIN=$(which grpc_cpp_plugin)
if [[ -z "$GRPC_PLUGIN" ]]; then
    echo "✗ grpc_cpp_plugin 未找到"
    exit 1
fi
echo "✓ grpc_cpp_plugin 找到: $GRPC_PLUGIN"

# 创建测试 gRPC proto 文件
cat > test_grpc.proto << 'EOL'
syntax = "proto3";

package test;

message TestRequest {
    string input = 1;
}

message TestResponse {
    string output = 1;
}

service TestService {
    rpc TestMethod (TestRequest) returns (TestResponse);
}
EOL

# 编译 gRPC proto 文件
protoc --grpc_out=. --cpp_out=. --plugin=protoc-gen-grpc=$GRPC_PLUGIN test_grpc.proto

if [[ -f "test_grpc.pb.cc" && -f "test_grpc.pb.h" && -f "test_grpc.grpc.pb.cc" && -f "test_grpc.grpc.pb.h" ]]; then
    echo "✓ gRPC 编译测试通过"
    rm test_grpc.pb.cc test_grpc.pb.h test_grpc.grpc.pb.cc test_grpc.grpc.pb.h test_grpc.proto
else
    echo "✗ gRPC 编译测试失败"
    exit 1
fi

# 3. 验证 Abseil (absl) 安装
echo -e "\n[3/3] 验证 Abseil (absl) 安装..."

# 创建测试程序
cat > test_absl.cc << 'EOL'
#include <iostream>
#include <string>
#include "absl/strings/str_cat.h"

int main() {
    std::string s1 = "Hello";
    std::string s2 = "World";
    std::string result = absl::StrCat(s1, ", ", s2, "!");
    std::cout << result << std::endl;
    return 0;
}
EOL

# 编译并运行测试程序
g++ -std=c++11 test_absl.cc -o test_absl -labsl_strings 2>/dev/null

if [[ $? -eq 0 ]]; then
    OUTPUT=$(./test_absl)
    if [[ "$OUTPUT" == "Hello, World!" ]]; then
        echo "✓ Abseil 测试程序运行成功"
        echo "程序输出: $OUTPUT"
        rm test_absl test_absl.cc
    else
        echo "✗ Abseil 测试程序输出不符合预期"
        echo "期望输出: Hello, World!"
        echo "实际输出: $OUTPUT"
        exit 1
    fi
else
    echo "✗ Abseil 测试程序编译失败"
    exit 1
fi

echo -e "\n=== 所有测试通过！protoc、gRPC 和 Abseil (absl) 安装验证成功 ==="
