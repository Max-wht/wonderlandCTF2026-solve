# Score CTF 漏洞分析报告

## 1. 范围
- 合约: `src/###-score/Challenge.sol`
- 合约: `src/###-score/Score.sol`
- 合约: `src/###-score/Oracle.sol`
- 接口: `src/###-score/IScore.sol`, `src/###-score/IOracle.sol`

## 2. 结论摘要
该题被攻破的根因不是单点 bug，而是多处设计缺陷可串联利用:
1. `Oracle` 的熵与 `rotation` 可被任意用户反复操控。
2. 当 `rotation == 0` 时，`Score.solve()` 的累加逻辑退化为纯异或线性系统。
3. `solve()` 缺少输入规模/范围限制，攻击者可以构造足够多向量做 GF(2) 高斯消元。
4. 最后的 gas 检查可由外部 `call{gas: x}` 直接扫描绕过，不能作为安全边界。

最终攻击者可稳定构造 `_indices` 使 `_accumulator == _target`，并通过 gas gate，清空 `Score` 余额（`isSolved == true`）。

## 3. 详细问题

### A. Oracle 随机性可控（高危）
### 位置
- `Oracle.contribute()`
- `Oracle.getRotation()`

### 现象
- `contribute(uint256 _value)` 只校验 `_value != 0`，没有:
  - 唯一贡献者限制（同地址可无限次调用）
  - 贡献成本约束（`msg.value` 与 `_value` 无绑定）
  - 调用频率限制
- `contributorCount` 按调用次数增加，不是“唯一贡献者数量”。
- `getRotation()` 的返回值依赖 `_entropy/_scale/contributorCount`，都可被攻击者批量调用改变。

### 影响
攻击者能在链上暴力刷新状态直到命中 `rotation == 0`（或任意目标 rotation）。

### 根因
把“可被任意人低成本反复写入”的状态当成随机源。

## B. `rotation == 0` 时算法退化为线性方程（高危）
### 位置
- `Score.solve()` 的 assembly 更新逻辑

### 现象
循环中核心逻辑:
- `mask = (1 << r) - 1`
- `temp = accumulator + (element & mask)`
- `temp = rotl(temp, r)`
- `accumulator = temp ^ element`

当 `r = 0`:
- `mask = 0`
- `temp = accumulator`
- `rotl(temp, 0) = temp`
- 所以 `accumulator = accumulator ^ element`

于是目标变成:
`XOR(getElement(i_k)) == generateTarget()`

这在 GF(2) 上是标准线性可解问题。

### 影响
攻击者可离线/链下对 256-bit 向量做高斯消元，求得一组 `_indices` 直接过校验。

### 根因
状态转移函数在某些参数（`r=0`）下退化为可线性求逆结构，缺乏退化态防护。

## C. `solve()` 缺少输入约束（中危）
### 位置
- `Score.solve(uint256[] calldata _indices)`

### 现象
`IScore` 定义了 `Score_NoIndices/Score_TooFewIndices/Score_IndexOutOfBounds`，但实现里未使用。

攻击者可以:
- 提交任意长度 `_indices`
- 提交任意大 index（`getElement` 只是 `keccak(seed, index, block.number)`）

### 影响
给了攻击者充足自由度收集线性基，显著降低求解难度和失败概率。

### 根因
接口层设计了约束意图，但实现层未落地。

## D. Gas Gate 不是安全机制（中危）
### 位置
- `Score.solve()` 末尾 gas 检查

### 现象
- 合约用 `gasleft()` 与 `_gasLimit` 比较决定 revert。
- 调用方可通过 `address(score).call{gas: g}(payload)` 细粒度控制进函数的 gas。
- 直接扫描 `g` 区间即可命中可通过窗口。

### 影响
该检查只能增加一点试错成本，无法阻止利用。

### 根因
把“调用 gas 形态”当作不可控条件；但它本质上是调用者可调参数。

## 4. 典型利用链
1. 反复调用 `Oracle.contribute(1)`，直到 `getRotation() == 0`。
2. 在同一 block 下读取:
   - `target = generateTarget()`
   - 大量 `element_i = getElement(i)`
3. 以 `element_i` 为 256 维 bit 向量做 GF(2) 消元，求子集 XOR = `target`。
4. 将求得索引数组传入 `solve()`。
5. 用外层合约 `call{gas: g}` 扫描 gas，绕过末尾 gas gate。
6. `Score` 10 ETH 转给 `PLAYER`，`isSolved()` 变为 `true`。

## 5. 修复建议
1. 强化 Oracle 随机源
- 统计唯一贡献者，避免同地址刷计数。
- 约束 `msg.value` 与贡献值关系，提升操控成本。
- 不使用可公开、可重复写入状态作为关键随机输入。
- 改为 commit-reveal 或使用可信随机源（如 VRF）。

2. 防止退化参数
- 禁止 `rotation == 0`（至少要求 `1..127`）。
- 审核状态转移函数在边界值下是否会退化为线性可逆结构。

3. 落实输入校验
- 对 `_indices` 长度做上下限检查。
- 对 index 范围做约束（例如 `< MAX_INDEX`）。
- 必要时限制重复索引和调用次数。

4. 移除/替代 gas 型“防护”
- 不要把 `gasleft()` 检查作为安全控制。
- 若需反机器人或反脚本，应使用签名、承诺机制、时序约束等可验证手段。

## 6. 风险评级
- 综合评级: **高危**
- 原因: 可稳定、低成本、可重复地触发 `isSolved` 条件，直接导致资金转出。
