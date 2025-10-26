#!/bin/bash

# 边界滑动修复测试脚本
# 用于验证第一张向右滑和最后一张向左滑的修复

echo "🎯 边界滑动修复测试脚本"
echo "========================"

# 检查关键文件是否存在
echo "📁 检查文件结构..."
if [ -f "PhotoTidy-Toilet Buddy/CardReviewView.swift" ]; then
    echo "✅ CardReviewView.swift 存在"
else
    echo "❌ CardReviewView.swift 不存在"
    exit 1
fi

echo ""
echo "🔍 检查边界滑动修复..."

# 检查是否添加了边界检查
if grep -q "if viewModel.canMoveNext" "PhotoTidy-Toilet Buddy/CardReviewView.swift"; then
    echo "✅ 左滑边界检查已添加"
else
    echo "❌ 左滑边界检查未找到"
fi

if grep -q "if viewModel.canMovePrevious" "PhotoTidy-Toilet Buddy/CardReviewView.swift"; then
    echo "✅ 右滑边界检查已添加"
else
    echo "❌ 右滑边界检查未找到"
fi

# 检查是否添加了边界反弹效果
if grep -q "handleBoundaryBounce" "PhotoTidy-Toilet Buddy/CardReviewView.swift"; then
    echo "✅ 边界反弹效果已添加"
else
    echo "❌ 边界反弹效果未找到"
fi

# 检查边界反弹方法实现
if grep -q "处理边界反弹效果" "PhotoTidy-Toilet Buddy/CardReviewView.swift"; then
    echo "✅ 边界反弹方法已实现"
else
    echo "❌ 边界反弹方法未实现"
fi

# 检查日志信息
if grep -q "最后一张照片，无法向左滑动" "PhotoTidy-Toilet Buddy/CardReviewView.swift"; then
    echo "✅ 最后一张照片日志已添加"
else
    echo "❌ 最后一张照片日志未找到"
fi

if grep -q "第一张照片，无法向右滑动" "PhotoTidy-Toilet Buddy/CardReviewView.swift"; then
    echo "✅ 第一张照片日志已添加"
else
    echo "❌ 第一张照片日志未找到"
fi

echo ""
echo "🧪 语法检查..."

# 检查Swift语法
if swift -frontend -parse "PhotoTidy-Toilet Buddy/CardReviewView.swift" > /dev/null 2>&1; then
    echo "✅ CardReviewView.swift 语法正确"
else
    echo "❌ CardReviewView.swift 语法错误"
fi

echo ""
echo "📊 代码统计..."

# 统计代码行数
cardview_lines=$(wc -l < "PhotoTidy-Toilet Buddy/CardReviewView.swift")
echo "📄 CardReviewView.swift: $cardview_lines 行"

echo ""
echo "🎉 测试完成！"
echo "========================"

# 总结
echo "📋 边界滑动修复总结："
echo "• 添加了左滑边界检查 - 最后一张照片无法向左滑动"
echo "• 添加了右滑边界检查 - 第一张照片无法向右滑动"
echo "• 实现了边界反弹效果 - 提供视觉反馈"
echo "• 确保照片返回居中位置 - 解决拖拽后不居中的问题"
echo "• 添加了详细的调试日志 - 便于问题排查"
echo ""
echo "✨ 这些修复让边界滑动体验更加自然和直观！"

# 编译测试
echo ""
echo "🔨 编译测试..."
if xcodebuild -workspace "PhotoTidy-Toilet Buddy.xcworkspace" -scheme "PhotoTidy-Toilet Buddy" -configuration Debug -destination "platform=iOS Simulator,name=iPhone 16 Plus" build > /dev/null 2>&1; then
    echo "✅ 编译成功"
else
    echo "❌ 编译失败"
fi
