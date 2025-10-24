# 单元测试快速参考

## 🚀 快速开始

```bash
# 1. 给脚本执行权限（只需一次）
chmod +x run_tests.sh

# 2. 运行所有测试
./run_tests.sh all

# 3. 运行特定类别
./run_tests.sh filter      # 过滤配置测试
./run_tests.sh date        # 日期范围测试
./run_tests.sh integration # 集成测试
```

---

## 📋 测试分类速查

### 按功能分类

| 测试类别 | 文件 | 测试数量 | 运行命令 |
|---------|------|---------|---------|
| **过滤配置** | FilterConfigurationTests | 30+ | `./run_tests.sh filter` |
| **日期范围** | DateRangeTests | 15+ | `./run_tests.sh date` |
| **内容类型** | ContentTypeTests | 20+ | `./run_tests.sh content` |
| **集成测试** | FilterLogicIntegrationTests | 15+ | `./run_tests.sh integration` |
| **边界情况** | EdgeCaseTests | 20+ | `./run_tests.sh edge` |
| **兼容性** | LegacyCompatibilityTests | 15+ | `./run_tests.sh legacy` |

---

## 🔍 关键测试方法速查

### 验证关键修复

```swift
// 1. 过滤优先级不丢失
FilterLogicIntegrationTests.testNoPriorityLoss_AllDimensions()

// 2. 连拍识别修复
LegacyCompatibilityTests.testBurstIdentifierFix()

// 3. 日期边界修复
DateRangeTests.testLastYear_DoesNotIncludeThisYear()

// 4. 矛盾配置检测
FilterConfigurationTests.testConflictingConfiguration_ImageWithDuration()
```

### 验证实际场景

```swift
// 清理旧截图
FilterConfigurationTests.testScenario_CleanOldScreenshots()

// 清理慢动作视频
FilterLogicIntegrationTests.testScenario_RecentSlowMotionLongVideos()

// 清理短视频
FilterLogicIntegrationTests.testScenario_RecentShortVideos()


### 验证边界情况

```swift
// nil 值处理
EdgeCaseTests.testNilOptionalFields()

// 空配置
EdgeCaseTests.testEmptyConfiguration()

// 并发安全
EdgeCaseTests.testConcurrency_ParallelValidations()

// 压力测试
EdgeCaseTests.testStress_ThousandsOfValidations()
```

---

## 🎯 测试矩阵速查

### 有效组合 ✅

| 配置示例 | 测试方法 |
|---------|---------|
| 截图 + 最近30天 | ✅ 有效 |
| 视频 + 短视频 | ✅ 有效 |
| 慢动作 + 1年前 + 含位置 | ✅ 有效 |
| 自拍 + 无位置 | ✅ 有效（有建议）|

### 无效组合 ❌

| 配置示例 | 测试方法 |
|---------|---------|
| 截图 + 短视频 | ❌ 矛盾（被检测）|
| 自拍 + 长视频 | ❌ 矛盾（被检测）|
| 全景 + 短视频 | ❌ 矛盾（被检测）|
| HDR + 长视频 | ❌ 矛盾（被检测）|

---

## 🐛 调试失败的测试

### 步骤 1：查看失败信息
```
Test Case '-[FilterConfigurationTests testConflictingConfiguration_ImageWithDuration]' failed
```

### 步骤 2：定位问题
```swift
// 查看测试代码
func testConflictingConfiguration_ImageWithDuration() {
    var config = FilterConfiguration()
    config.contentType = .screenshots
    config.durationFilter = .shortVideos
    
    let validation = config.validate()
    XCTAssertFalse(validation.isValid)  // ← 这里失败了
}
```

### 步骤 3：检查实现
```swift
// 检查 FilterConfiguration.validate()
// 验证是否正确检测矛盾
```

### 步骤 4：修复或更新测试

---

## 📈 测试覆盖率报告

### 查看覆盖率
```bash
# 生成覆盖率报告
./run_tests.sh coverage

# 查看报告
open DerivedData/Logs/Test/*.xcresult
```

### 目标覆盖率

| 模块 | 目标 | 当前 |
|-----|------|------|
| FilterConfiguration | 100% | ~95% |
| ContentType | 100% | 100% |
| DateRangeType | 100% | 100% |
| LocationFilterType | 100% | 100% |
| DurationFilterType | 100% | 100% |
| 验证逻辑 | 100% | ~90% |

---

## 💡 测试最佳实践

### ✅ 好的测试
```swift
func testValidConfiguration() {
    // 1. 明确的设置
    var config = FilterConfiguration()
    config.contentType = .screenshots
    
    // 2. 清晰的断言
    let validation = config.validate()
    XCTAssertTrue(validation.isValid, "有效配置应该通过验证")
    
    // 3. 有意义的错误消息
    XCTAssertTrue(config.summary.contains("截图"), "摘要应该包含内容类型")
}
```

### ❌ 不好的测试
```swift
func testSomething() {
    let config = FilterConfiguration()
    XCTAssertNotNil(config)  // 太简单，没有价值
}
```

---

## 🔧 常见问题

### Q: 测试运行很慢？
A: 检查性能测试中的循环次数，可以临时减少

### Q: 某些测试在 CI 上失败但本地通过？
A: 检查时区设置和日期计算逻辑

### Q: 如何只运行失败的测试？
A: 在 Xcode 中，点击测试导航器中的失败测试

### Q: 如何添加新测试？
A: 在相应的测试文件中添加新方法，遵循命名规范

---

## 📞 获取帮助

查看详细文档：
- `README_TESTS.md` - 测试套件说明
- `TEST_COVERAGE.md` - 覆盖率详情
- 各测试文件的注释

---

**最后更新：2025-10-22**

