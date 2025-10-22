#!/bin/bash

# Photo Tidy - Filter Logic Tests Runner
# 运行所有单元测试并生成报告

set -e

echo "🧪 Photo Tidy - 运行过滤逻辑单元测试"
echo "========================================"
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 配置
SCHEME="PhotoTidy-Toilet Buddy"
DESTINATION="platform=iOS Simulator,name=iPhone 15"

# 检查是否安装了 Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ 错误：未找到 xcodebuild${NC}"
    echo "请安装 Xcode Command Line Tools"
    exit 1
fi

echo -e "${YELLOW}📱 目标设备：iPhone 15 模拟器${NC}"
echo ""

# 选项：运行哪些测试
if [ "$1" == "all" ] || [ -z "$1" ]; then
    echo -e "${GREEN}▶️  运行所有测试...${NC}"
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -enableCodeCoverage YES \
        | grep -E "Test Suite|Test Case|passed|failed|[0-9]+ tests"
        
elif [ "$1" == "filter" ]; then
    echo -e "${GREEN}▶️  运行 FilterConfigurationTests...${NC}"
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:PhotoTidy-Toilet_BuddyTests/FilterConfigurationTests
        
elif [ "$1" == "date" ]; then
    echo -e "${GREEN}▶️  运行 DateRangeTests...${NC}"
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:PhotoTidy-Toilet_BuddyTests/DateRangeTests
        
elif [ "$1" == "content" ]; then
    echo -e "${GREEN}▶️  运行 ContentTypeTests...${NC}"
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:PhotoTidy-Toilet_BuddyTests/ContentTypeTests
        
elif [ "$1" == "integration" ]; then
    echo -e "${GREEN}▶️  运行 FilterLogicIntegrationTests...${NC}"
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:PhotoTidy-Toilet_BuddyTests/FilterLogicIntegrationTests
        
elif [ "$1" == "edge" ]; then
    echo -e "${GREEN}▶️  运行 EdgeCaseTests...${NC}"
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:PhotoTidy-Toilet_BuddyTests/EdgeCaseTests
        
elif [ "$1" == "legacy" ]; then
    echo -e "${GREEN}▶️  运行 LegacyCompatibilityTests...${NC}"
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -only-testing:PhotoTidy-Toilet_BuddyTests/LegacyCompatibilityTests
        
elif [ "$1" == "coverage" ]; then
    echo -e "${GREEN}▶️  生成测试覆盖率报告...${NC}"
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        -enableCodeCoverage YES \
        -derivedDataPath ./DerivedData
    
    echo ""
    echo -e "${GREEN}✅ 覆盖率报告已生成${NC}"
    echo "查看：./DerivedData/Logs/Test/*.xcresult"
    
else
    echo -e "${RED}❌ 未知的测试类型：$1${NC}"
    echo ""
    echo "用法："
    echo "  ./run_tests.sh [all|filter|date|content|integration|edge|legacy|coverage]"
    echo ""
    echo "示例："
    echo "  ./run_tests.sh all          # 运行所有测试"
    echo "  ./run_tests.sh filter       # 只运行 FilterConfigurationTests"
    echo "  ./run_tests.sh date         # 只运行 DateRangeTests"
    echo "  ./run_tests.sh coverage     # 生成覆盖率报告"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ 测试完成！${NC}"

