#!/bin/bash

# Photo Tidy - App Store 提交准备检查脚本
# 此脚本检查应用是否准备好提交到 App Store

echo "========================================"
echo "📱 Photo Tidy - App Store 提交准备检查"
echo "========================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查结果计数
PASSED=0
FAILED=0
WARNINGS=0

# 检查函数
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

echo "1️⃣  检查项目配置文件"
echo "---"

# 检查 Info.plist
if [ -f "PhotoTidy-Toilet Buddy/Info.plist" ]; then
    check_pass "Info.plist 文件存在"
    
    # 检查 Bundle ID
    BUNDLE_ID=$(grep -A 1 "CFBundleIdentifier" "PhotoTidy-Toilet Buddy/Info.plist" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
    if [ "$BUNDLE_ID" == '$(PRODUCT_BUNDLE_IDENTIFIER)' ]; then
        check_pass "Bundle ID 配置正确 (使用变量)"
    else
        check_fail "Bundle ID 配置异常: $BUNDLE_ID"
    fi
    
    # 检查 Display Name
    DISPLAY_NAME=$(grep -A 1 "CFBundleDisplayName" "PhotoTidy-Toilet Buddy/Info.plist" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
    if [ ! -z "$DISPLAY_NAME" ]; then
        check_pass "应用显示名称: $DISPLAY_NAME"
    else
        check_warn "未找到 CFBundleDisplayName"
    fi
    
    # 检查版本号
    VERSION=$(grep -A 1 "CFBundleShortVersionString" "PhotoTidy-Toilet Buddy/Info.plist" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
    if [ ! -z "$VERSION" ]; then
        check_pass "版本号: $VERSION"
    else
        check_fail "未找到版本号"
    fi
    
    # 检查构建号
    BUILD=$(grep -A 1 "CFBundleVersion" "PhotoTidy-Toilet Buddy/Info.plist" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
    if [ ! -z "$BUILD" ]; then
        check_pass "构建号: $BUILD"
    else
        check_fail "未找到构建号"
    fi
    
    # 检查照片库权限说明
    PHOTO_PERMISSION=$(grep -A 1 "NSPhotoLibraryUsageDescription" "PhotoTidy-Toilet Buddy/Info.plist" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
    if [ ! -z "$PHOTO_PERMISSION" ]; then
        check_pass "照片库权限说明已配置"
    else
        check_fail "缺少照片库权限说明"
    fi
    
    # 检查 AdMob App ID
    ADMOB_ID=$(grep -A 1 "GADApplicationIdentifier" "PhotoTidy-Toilet Buddy/Info.plist" | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
    if [ ! -z "$ADMOB_ID" ]; then
        if [[ $ADMOB_ID == ca-app-pub-2034595640300550~4044769988 ]]; then
            check_pass "AdMob App ID: $ADMOB_ID (正式ID)"
        elif [[ $ADMOB_ID == *"3940256099942544"* ]]; then
            check_fail "⚠️ 警告: 使用的是测试 AdMob ID，提交前必须替换！"
        else
            check_pass "AdMob App ID: $ADMOB_ID"
        fi
    else
        check_fail "未找到 AdMob App ID"
    fi
else
    check_fail "Info.plist 文件不存在"
fi

echo ""
echo "2️⃣  检查应用图标"
echo "---"

ICON_DIR="PhotoTidy-Toilet Buddy/Assets.xcassets/AppIcon.appiconset"
if [ -d "$ICON_DIR" ]; then
    check_pass "AppIcon.appiconset 目录存在"
    
    # 检查各种尺寸的图标
    ICON_FILES=(
        "icon-1024.png"
        "icon-20.png" "icon-20@2x.png" "icon-20@3x.png"
        "icon-29.png" "icon-29@2x.png" "icon-29@3x.png"
        "icon-40.png" "icon-40@2x.png" "icon-40@3x.png"
        "icon-60@2x.png" "icon-60@3x.png"
        "icon-76.png" "icon-76@2x.png"
        "icon-83.5@2x.png"
    )
    
    ICON_COUNT=0
    for icon in "${ICON_FILES[@]}"; do
        if [ -f "$ICON_DIR/$icon" ]; then
            ((ICON_COUNT++))
        fi
    done
    
    if [ $ICON_COUNT -eq ${#ICON_FILES[@]} ]; then
        check_pass "所有应用图标文件完整 ($ICON_COUNT/${#ICON_FILES[@]})"
    elif [ $ICON_COUNT -gt 0 ]; then
        check_warn "部分应用图标文件缺失 ($ICON_COUNT/${#ICON_FILES[@]})"
    else
        check_fail "应用图标文件缺失"
    fi
else
    check_fail "AppIcon.appiconset 目录不存在"
fi

echo ""
echo "3️⃣  检查必需文件"
echo "---"

# 检查隐私政策
if [ -f "docs/privacy.html" ]; then
    check_pass "隐私政策文件存在"
    
    # 检查是否包含必要内容
    if grep -q "AdMob" "docs/privacy.html"; then
        check_pass "隐私政策包含 AdMob 说明"
    else
        check_warn "隐私政策可能缺少 AdMob 相关说明"
    fi
else
    check_fail "隐私政策文件不存在"
fi

# 检查支持页面
if [ -f "docs/support.html" ]; then
    check_pass "支持页面存在"
else
    check_warn "支持页面不存在"
fi

# 检查主页
if [ -f "docs/index.html" ]; then
    check_pass "应用主页存在"
else
    check_warn "应用主页不存在"
fi

echo ""
echo "4️⃣  检查本地化"
echo "---"

# 检查中文本地化
if [ -f "PhotoTidy-Toilet Buddy/zh-Hans.lproj/Localizable.strings" ]; then
    check_pass "中文本地化文件存在"
else
    check_warn "中文本地化文件不存在"
fi

# 检查英文本地化
if [ -f "PhotoTidy-Toilet Buddy/en.lproj/Localizable.strings" ]; then
    check_pass "英文本地化文件存在"
else
    check_warn "英文本地化文件不存在"
fi

echo ""
echo "5️⃣  检查 AdMob 配置"
echo "---"

if [ -f "PhotoTidy-Toilet Buddy/AdManager.swift" ]; then
    check_pass "AdManager.swift 文件存在"
    
    # 检查测试广告 ID
    if grep -q "3940256099942544" "PhotoTidy-Toilet Buddy/AdManager.swift"; then
        check_fail "⚠️ AdManager.swift 中使用测试广告 ID，提交前必须替换！"
    else
        check_pass "AdManager.swift 中未发现测试广告 ID"
    fi
    
    # 检查是否有广告单元 ID
    if grep -q "ca-app-pub-" "PhotoTidy-Toilet Buddy/AdManager.swift"; then
        check_pass "AdManager.swift 中配置了广告单元 ID"
    else
        check_warn "AdManager.swift 中可能缺少广告单元 ID"
    fi
else
    check_fail "AdManager.swift 文件不存在"
fi

echo ""
echo "6️⃣  检查 CocoaPods 依赖"
echo "---"

if [ -f "Podfile" ]; then
    check_pass "Podfile 存在"
    
    if [ -f "Podfile.lock" ]; then
        check_pass "Podfile.lock 存在"
    else
        check_warn "Podfile.lock 不存在，建议运行 pod install"
    fi
    
    if [ -d "Pods" ]; then
        check_pass "Pods 目录存在"
        
        # 检查 Google-Mobile-Ads-SDK
        if [ -d "Pods/Google-Mobile-Ads-SDK" ]; then
            check_pass "Google-Mobile-Ads-SDK 已安装"
        else
            check_fail "Google-Mobile-Ads-SDK 未安装"
        fi
    else
        check_fail "Pods 目录不存在，需要运行 pod install"
    fi
else
    check_fail "Podfile 不存在"
fi

echo ""
echo "7️⃣  检查项目文件"
echo "---"

if [ -f "PhotoTidy-Toilet Buddy.xcworkspace/contents.xcworkspacedata" ]; then
    check_pass "Xcode Workspace 文件存在"
else
    check_fail "Xcode Workspace 文件不存在"
fi

if [ -f "PhotoTidy-Toilet Buddy.xcodeproj/project.pbxproj" ]; then
    check_pass "Xcode Project 文件存在"
    
    # 检查 Bundle Identifier
    if grep -q "com.phototidy.toiletbuddy" "PhotoTidy-Toilet Buddy.xcodeproj/project.pbxproj"; then
        check_pass "Bundle Identifier 已配置: com.phototidy.toiletbuddy"
    else
        check_warn "Bundle Identifier 配置可能有问题"
    fi
    
    # 检查 Development Team
    if grep -q "DEVELOPMENT_TEAM = KFV95PX9HR" "PhotoTidy-Toilet Buddy.xcodeproj/project.pbxproj"; then
        check_pass "Development Team 已配置"
    else
        check_warn "Development Team 可能未配置"
    fi
else
    check_fail "Xcode Project 文件不存在"
fi

echo ""
echo "8️⃣  检查关键源代码文件"
echo "---"

REQUIRED_FILES=(
    "PhotoTidy-Toilet Buddy/PhotoTidyToiletBuddyApp.swift"
    "PhotoTidy-Toilet Buddy/ContentView.swift"
    "PhotoTidy-Toilet Buddy/CardReviewView.swift"
    "PhotoTidy-Toilet Buddy/SessionSetupView.swift"
    "PhotoTidy-Toilet Buddy/SessionCompleteView.swift"
    "PhotoTidy-Toilet Buddy/TidySessionViewModel.swift"
    "PhotoTidy-Toilet Buddy/PhotoService.swift"
    "PhotoTidy-Toilet Buddy/AdManager.swift"
    "PhotoTidy-Toilet Buddy/Settings.swift"
    "PhotoTidy-Toilet Buddy/SettingsView.swift"
)

MISSING_FILES=0
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        ((PASSED++))
    else
        check_fail "缺少文件: $file"
        ((MISSING_FILES++))
        ((FAILED++))
    fi
done

if [ $MISSING_FILES -eq 0 ]; then
    check_pass "所有关键源代码文件完整"
fi

echo ""
echo "=========================================="
echo "📊 检查结果总结"
echo "=========================================="
echo ""
echo -e "${GREEN}✓ 通过: $PASSED${NC}"
echo -e "${YELLOW}⚠ 警告: $WARNINGS${NC}"
echo -e "${RED}✗ 失败: $FAILED${NC}"
echo ""

# 提供建议
if [ $FAILED -gt 0 ]; then
    echo "❌ 发现 $FAILED 个严重问题，需要修复后才能提交。"
    echo ""
    echo "请参考 APP_STORE_SUBMISSION_GUIDE.md 获取详细指导。"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo "⚠️  发现 $WARNINGS 个警告，建议处理后再提交。"
    echo ""
    echo "这些警告不会阻止提交，但可能影响审核结果。"
    exit 0
else
    echo "✅ 所有检查通过！应用已准备好提交到 App Store。"
    echo ""
    echo "下一步："
    echo "1. 在 Xcode 中选择 Product → Archive"
    echo "2. 验证并上传到 App Store Connect"
    echo "3. 在 App Store Connect 中配置元数据"
    echo "4. 提交审核"
    echo ""
    echo "详细步骤请参考 APP_STORE_SUBMISSION_GUIDE.md"
    exit 0
fi

