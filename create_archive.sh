#!/bin/bash

# Photo Tidy - 创建Archive构建脚本
# 自动创建用于App Store上传的Archive

set -e

echo "🚀 Photo Tidy - 创建Archive构建"
echo "================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查函数
check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
}

check_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

check_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 1. 预检查
echo "🔍 1. 预检查"
echo "-------------"

# 检查Xcode是否安装
if ! command -v xcodebuild &> /dev/null; then
    check_error "Xcode未安装或未配置命令行工具"
    exit 1
fi
check_pass "Xcode命令行工具已安装"

# 检查项目文件
if [ ! -f "PhotoTidy-Toilet Buddy.xcworkspace/contents.xcworkspacedata" ]; then
    check_error "找不到workspace文件"
    exit 1
fi
check_pass "Workspace文件存在"

# 检查AdMob配置
ADMOB_ID=$(grep -A1 "GADApplicationIdentifier" "PhotoTidy-Toilet Buddy/Info.plist" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
# 检查是否为真正的测试ID
if [[ $ADMOB_ID == *"3940256099942544"* ]] || [[ $ADMOB_ID == *"test"* ]]; then
    check_warning "AdMob ID为测试ID: $ADMOB_ID"
    echo "   建议先替换为正式ID再创建Archive"
    echo ""
    read -p "是否继续使用测试ID创建Archive? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "已取消Archive创建"
        exit 0
    fi
else
    check_pass "AdMob ID为正式ID: $ADMOB_ID"
fi

echo ""

# 2. 清理项目
echo "🧹 2. 清理项目"
echo "---------------"

check_info "正在清理项目..."
if xcodebuild -workspace "PhotoTidy-Toilet Buddy.xcworkspace" -scheme "PhotoTidy-Toilet Buddy" clean > /dev/null 2>&1; then
    check_pass "项目清理完成"
else
    check_error "项目清理失败"
    exit 1
fi

echo ""

# 3. 创建Archive
echo "📦 3. 创建Archive"
echo "------------------"

check_info "正在创建Archive..."
echo "这可能需要几分钟时间，请耐心等待..."

# 创建Archive
ARCHIVE_PATH="./PhotoTidy-Toilet Buddy.xcarchive"

if xcodebuild -workspace "PhotoTidy-Toilet Buddy.xcworkspace" \
    -scheme "PhotoTidy-Toilet Buddy" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    archive; then
    
    check_pass "Archive创建成功"
    check_info "Archive位置: $ARCHIVE_PATH"
else
    check_error "Archive创建失败"
    exit 1
fi

echo ""

# 4. 验证Archive
echo "✅ 4. 验证Archive"
echo "------------------"

check_info "正在验证Archive..."

# 检查Archive文件是否存在
if [ -d "$ARCHIVE_PATH" ]; then
    check_pass "Archive文件存在"
    
    # 获取Archive信息
    ARCHIVE_SIZE=$(du -sh "$ARCHIVE_PATH" | cut -f1)
    check_info "Archive大小: $ARCHIVE_SIZE"
    
    # 检查Archive内容
    if [ -f "$ARCHIVE_PATH/Info.plist" ]; then
        check_pass "Archive结构正确"
    else
        check_error "Archive结构异常"
        exit 1
    fi
else
    check_error "Archive文件不存在"
    exit 1
fi

echo ""

# 5. 显示后续步骤
echo "🚀 5. 后续步骤"
echo "---------------"

echo ""
echo "Archive创建完成！接下来你可以："
echo ""
echo "📱 在Xcode中上传到App Store Connect:"
echo "   1. 打开Xcode"
echo "   2. 选择 Window → Organizer"
echo "   3. 选择 Archives 标签"
echo "   4. 找到刚创建的Archive"
echo "   5. 点击 'Distribute App'"
echo "   6. 选择 'App Store Connect' → 'Upload'"
echo ""
echo "📋 在App Store Connect中配置:"
echo "   1. 登录 https://appstoreconnect.apple.com"
echo "   2. 创建新应用或选择现有应用"
echo "   3. 填写应用元数据 (参考 APP_STORE_METADATA.txt)"
echo "   4. 上传截图"
echo "   5. 选择构建版本"
echo "   6. 提交审核"
echo ""
echo "📖 参考文档:"
echo "   - APP_STORE_UPLOAD_READY.md (上传准备总结)"
echo "   - APP_STORE_SUBMISSION_GUIDE.md (详细指南)"
echo "   - APP_STORE_METADATA.txt (元数据模板)"
echo ""

# 6. 重要提醒
echo "⚠️  6. 重要提醒"
echo "---------------"

# 检查是否为真正的测试ID
if [[ $ADMOB_ID == *"3940256099942544"* ]] || [[ $ADMOB_ID == *"test"* ]]; then
    check_warning "AdMob ID为测试ID"
    echo "   上传前请务必替换为正式ID"
    echo "   测试ID会导致审核被拒"
else
    check_pass "AdMob ID为正式ID，可以安全上传"
fi

echo ""
echo "🎉 Archive创建完成！"
echo "====================="
echo ""
echo "Archive位置: $ARCHIVE_PATH"
echo "大小: $ARCHIVE_SIZE"
echo ""
echo "现在可以在Xcode Organizer中上传到App Store Connect了！"
echo ""
echo "祝你上架顺利！🚀"
